import 'package:flutter/foundation.dart';

import '../../data/repositories/worker_chatbot_repository.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/chat_policy.dart';
import '../../domain/repositories/chatbot_repository.dart';

/// UI-facing lifecycle for one chatbot request.
enum ChatbotRequestState { idle, sending, success, error }

class ChatbotController extends ChangeNotifier {
  ChatbotController(this._repository);

  final ChatbotRepository _repository;
  final List<ChatMessage> _messages = [];

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  ChatbotRequestState _requestState = ChatbotRequestState.idle;
  ChatbotRequestState get requestState => _requestState;
  bool get isSending => _requestState == ChatbotRequestState.sending;
  String? _errorMessage;
  String? get errorMessage => _errorMessage;
  bool _disposed = false;
  int _epoch = 0;
  String? _userId;

  /// Authentication changes invalidate even an in-flight response.
  void bindUser(String? userId) {
    if (_userId == userId) return;
    _userId = userId;
    _epoch++;
    _messages.clear();
    _errorMessage = null;
    _requestState = ChatbotRequestState.idle;
  }

  Future<void> send(String draft) async {
    final text = draft.trim();
    if (_disposed || text.isEmpty || isSending) return;
    final validation = ChatPolicy.validate(text);
    if (validation != null) {
      _errorMessage = validation;
      _requestState = ChatbotRequestState.error;
      notifyListeners();
      return;
    }
    // Replace a failed turn when a different question is submitted.
    if (_messages.isNotEmpty && _messages.last.isUser) _messages.removeLast();
    _messages.add(ChatMessage(role: ChatMessageRole.user, text: text));
    await _requestReply();
  }

  Future<void> retry() async {
    if (isSending || _messages.isEmpty || !_messages.last.isUser) return;
    await _requestReply();
  }

  Future<void> _requestReply() async {
    final epoch = _epoch;
    _requestState = ChatbotRequestState.sending;
    _errorMessage = null;
    notifyListeners();
    try {
      final reply = await _repository.sendMessage(
        message: _messages.last.text,
        history: List.unmodifiable(_messages),
      );
      if (_disposed || epoch != _epoch) return;
      if (reply.trim().isEmpty || reply.length > ChatPolicy.maxMessageLength) {
        throw const ChatbotException('Trợ lý không trả về nội dung hợp lệ.');
      }
      _messages.add(ChatMessage(role: ChatMessageRole.assistant, text: reply));
      _requestState = ChatbotRequestState.success;
    } on ChatbotException catch (error) {
      if (_disposed || epoch != _epoch) return;
      _errorMessage = error.message;
      _requestState = ChatbotRequestState.error;
    } catch (_) {
      if (_disposed || epoch != _epoch) return;
      _errorMessage = 'Không thể gửi tin nhắn lúc này. Vui lòng thử lại.';
      _requestState = ChatbotRequestState.error;
    } finally {
      if (!_disposed && epoch == _epoch) notifyListeners();
    }
  }

  void reset() {
    if (isSending || (_messages.isEmpty && _errorMessage == null)) return;
    _messages.clear();
    _errorMessage = null;
    _requestState = ChatbotRequestState.idle;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _epoch++;
    _messages.clear();
    super.dispose();
  }
}
