// Public dependency names are intentional for constructor injection.
// ignore_for_file: prefer_initializing_formals

import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../../domain/entities/chat_message.dart';
import '../../domain/chat_policy.dart';
import '../../domain/repositories/chatbot_repository.dart';

class ChatbotException implements Exception {
  const ChatbotException(this.message);

  final String message;
}

class ChatIdentity {
  const ChatIdentity(this.userId, this.token);
  final String userId;
  final String token;
}

/// Calls the Cloudflare Worker, never OpenAI directly from the mobile app.
class WorkerChatbotRepository implements ChatbotRepository {
  WorkerChatbotRepository({
    http.Client? client,
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    Future<ChatIdentity?> Function()? identityProvider,
    Future<void> Function(Map<String, dynamic>)? persistHistory,
    String endpoint = _workerUrl,
    Duration requestTimeout = const Duration(seconds: 28),
  }) : _client = client ?? http.Client(),
       _auth = auth,
       _firestore = firestore,
       _identityProvider = identityProvider,
       _persistHistory = persistHistory,
       _endpoint = endpoint,
       _requestTimeout = requestTimeout;

  // This is a public Worker endpoint, not an OpenAI credential. A compile-time
  // value can still override it for staging or a future production Worker.
  static const _workerUrl = String.fromEnvironment(
    'CHATBOT_WORKER_URL',
    defaultValue: 'https://healway-chatbot.healway-hospital.workers.dev',
  );

  final http.Client _client;
  final FirebaseAuth? _auth;
  final FirebaseFirestore? _firestore;
  final Future<ChatIdentity?> Function()? _identityProvider;
  final Future<void> Function(Map<String, dynamic>)? _persistHistory;
  final String _endpoint;
  final Duration _requestTimeout;
  String? _sessionId;
  String? _sessionUserId;

  @override
  Future<String> sendMessage({
    required String message,
    required List<ChatMessage> history,
  }) async {
    for (final value in [message, ...history.map((item) => item.text)]) {
      final error = ChatPolicy.validate(value);
      if (error != null) throw ChatbotException(error);
    }
    final endpoint = Uri.tryParse(_endpoint);
    if (endpoint == null ||
        endpoint.scheme != 'https' ||
        endpoint.host.isEmpty ||
        endpoint.userInfo.isNotEmpty ||
        endpoint.hasQuery ||
        endpoint.hasFragment) {
      throw const ChatbotException(
        'Dịch vụ trợ lý chưa được cấu hình. Vui lòng thử lại sau.',
      );
    }
    final identity = await _identity();
    if (identity == null || identity.token.isEmpty) {
      throw const ChatbotException('Bạn cần đăng nhập để dùng trợ lý HealWay.');
    }
    if (history.isEmpty ||
        !history.last.isUser ||
        history.last.text != message) {
      throw const ChatbotException('Lịch sử trò chuyện không hợp lệ.');
    }
    final boundedHistory = history.length <= 12
        ? history
        : history.sublist(history.length - 12);
    final response = await _post(identity.token, message, boundedHistory);
    final reply = _replyFrom(response);
    if ((await _identity())?.userId != identity.userId) {
      throw const ChatbotException('Phiên đăng nhập đã thay đổi.');
    }
    await _saveHistory(
      userId: identity.userId,
      userMessage: message,
      aiReply: reply,
    );
    return reply;
  }

  Future<ChatIdentity?> _identity() async {
    if (_identityProvider != null) return _identityProvider();
    final user = (_auth ?? FirebaseAuth.instance).currentUser;
    if (user == null) return null;
    final token = await user.getIdToken();
    return token == null ? null : ChatIdentity(user.uid, token);
  }

  Future<http.Response> _post(
    String token,
    String message,
    List<ChatMessage> history,
  ) async {
    try {
      return await _client
          .post(
            Uri.parse('${_endpoint.replaceFirst(RegExp(r'/+$'), '')}/chat'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'message': message,
              'history': history.map((item) => item.toRequestJson()).toList(),
            }),
          )
          .timeout(_requestTimeout);
    } on http.ClientException {
      throw const ChatbotException(
        'Không thể kết nối đến trợ lý lúc này. Vui lòng thử lại.',
      );
    } on TimeoutException {
      throw const ChatbotException(
        'Trợ lý đang phản hồi chậm. Vui lòng thử lại sau ít phút.',
      );
    }
  }

  String _replyFrom(http.Response response) {
    Map<String, dynamic>? data;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) data = decoded;
    } on FormatException {
      // Convert malformed responses to a safe message below.
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ChatbotException(_messageForStatus(response.statusCode));
    }
    final reply = data?['reply'];
    if (reply is! String || reply.trim().isEmpty || reply.length > 2000) {
      throw const ChatbotException(
        'Trợ lý không trả về nội dung hợp lệ. Vui lòng thử lại.',
      );
    }
    return reply.trim();
  }

  Future<void> _saveHistory({
    required String userId,
    required String userMessage,
    required String aiReply,
  }) async {
    if (_sessionUserId != userId || _sessionId == null) {
      _sessionUserId = userId;
      _sessionId = '${userId}_${DateTime.now().microsecondsSinceEpoch}';
    }
    try {
      final data = <String, dynamic>{
        'authUserId': userId,
        'userId': userId,
        'sessionId': _sessionId,
        'userMessage': userMessage,
        'aiReply': aiReply,
        'source': 'OPENAI_CLOUDFLARE',
        'timestamp': FieldValue.serverTimestamp(),
      };
      if (_persistHistory != null) {
        await _persistHistory(data).timeout(const Duration(seconds: 5));
      } else {
        await (_firestore ?? FirebaseFirestore.instance)
            .collection('LS_CHAT_AI')
            .add(data)
            .timeout(const Duration(seconds: 5));
      }
    } catch (_) {
      // A history-write problem must not discard a valid AI response.
    }
  }

  String _messageForStatus(int status) {
    return switch (status) {
      401 => 'Bạn cần đăng nhập để dùng trợ lý HealWay.',
      403 => 'Tài khoản của bạn không có quyền dùng trợ lý.',
      400 => 'Tin nhắn không hợp lệ. Vui lòng nhập lại.',
      422 => ChatPolicy.privacyMessage,
      429 => 'Bạn gửi tin nhắn quá nhanh. Vui lòng chờ một lát rồi thử lại.',
      504 => 'Trợ lý đang phản hồi chậm. Vui lòng thử lại sau ít phút.',
      502 ||
      503 => 'Dịch vụ trợ lý tạm thời không khả dụng. Vui lòng thử lại sau.',
      _ => 'Không thể gửi tin nhắn lúc này. Vui lòng thử lại.',
    };
  }
}
