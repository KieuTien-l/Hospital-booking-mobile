import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../../domain/entities/chat_message.dart';
import '../../domain/repositories/chatbot_repository.dart';

class ChatbotException implements Exception {
  const ChatbotException(this.message);

  final String message;
}

/// Calls the Cloudflare Worker, never OpenAI directly from the mobile app.
class WorkerChatbotRepository implements ChatbotRepository {
  WorkerChatbotRepository({
    http.Client? client,
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  }) : _client = client ?? http.Client(),
       _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance;

  // This is a public Worker endpoint, not an OpenAI credential. A compile-time
  // value can still override it for staging or a future production Worker.
  static const _workerUrl = String.fromEnvironment(
    'CHATBOT_WORKER_URL',
    defaultValue: 'https://healway-chatbot.healway-hospital.workers.dev',
  );

  final http.Client _client;
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  String? _sessionId;
  String? _sessionUserId;

  @override
  Future<String> sendMessage({
    required String message,
    required List<ChatMessage> history,
  }) async {
    if (_workerUrl.isEmpty) {
      throw const ChatbotException(
        'Dịch vụ trợ lý chưa được cấu hình. Vui lòng thử lại sau.',
      );
    }
    final user = _auth.currentUser;
    if (user == null) {
      throw const ChatbotException('Bạn cần đăng nhập để dùng trợ lý HealWay.');
    }
    final token = await user.getIdToken();
    if (token == null) {
      throw const ChatbotException(
        'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
      );
    }
    final boundedHistory = history.length <= 12
        ? history
        : history.sublist(history.length - 12);
    final response = await _post(token, message, boundedHistory);
    final reply = _replyFrom(response);
    await _saveHistory(userId: user.uid, userMessage: message, aiReply: reply);
    return reply;
  }

  Future<http.Response> _post(
    String token,
    String message,
    List<ChatMessage> history,
  ) async {
    try {
      return await _client
          .post(
            Uri.parse('${_workerUrl.replaceFirst(RegExp(r'/+$'), '')}/chat'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'message': message,
              'history': history.map((item) => item.toRequestJson()).toList(),
            }),
          )
          .timeout(const Duration(seconds: 28));
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
      throw ChatbotException(
        _messageForStatus(response.statusCode, data?['error']),
      );
    }
    final reply = data?['reply'];
    if (reply is! String || reply.trim().isEmpty) {
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
      await _firestore.collection('LS_CHAT_AI').add({
        'authUserId': userId,
        'userId': userId,
        'sessionId': _sessionId,
        'userMessage': userMessage,
        'aiReply': aiReply,
        'source': 'OPENAI_CLOUDFLARE',
        'timestamp': FieldValue.serverTimestamp(),
      });
    } on FirebaseException {
      // A history-write problem must not discard a valid AI response.
    }
  }

  String _messageForStatus(int status, Object? error) {
    if (error is String && error.isNotEmpty && error.length <= 200) {
      return error;
    }
    return switch (status) {
      401 => 'Bạn cần đăng nhập để dùng trợ lý HealWay.',
      403 => 'Tài khoản của bạn không có quyền dùng trợ lý.',
      400 => 'Tin nhắn không hợp lệ. Vui lòng nhập lại.',
      429 => 'Bạn gửi tin nhắn quá nhanh. Vui lòng chờ một lát rồi thử lại.',
      504 => 'Trợ lý đang phản hồi chậm. Vui lòng thử lại sau ít phút.',
      502 ||
      503 => 'Dịch vụ trợ lý tạm thời không khả dụng. Vui lòng thử lại sau.',
      _ => 'Không thể gửi tin nhắn lúc này. Vui lòng thử lại.',
    };
  }
}
