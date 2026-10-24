import 'package:flutter/foundation.dart';

import '../../data/repositories/worker_chatbot_repository.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/repositories/chatbot_repository.dart';

class ChatbotController extends ChangeNotifier {
  ChatbotController(this._repository);

  final ChatbotRepository _repository;
  final List<ChatMessage> _messages = [];

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool _isSending = false;
  bool get isSending => _isSending;
  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Future<void> send(String draft) async {
    final text = draft.trim();
    if (text.isEmpty || _isSending) return;
    _messages.add(ChatMessage(role: ChatMessageRole.user, text: text));
    await _requestReply();
  }

  Future<void> retry() async {
    if (_isSending || _messages.isEmpty || !_messages.last.isUser) return;
    await _requestReply();
  }

  Future<void> _requestReply() async {
    _isSending = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final reply = await _repository.sendMessage(
        message: _messages.last.text,
        history: _messages,
      );
      _messages.add(ChatMessage(role: ChatMessageRole.assistant, text: reply));
    } on ChatbotException catch (error) {
      _errorMessage = error.message;
    } catch (_) {
      _errorMessage = 'Không thể gửi tin nhắn lúc này. Vui lòng thử lại.';
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  void reset() {
    if (_isSending || (_messages.isEmpty && _errorMessage == null)) return;
    _messages.clear();
    _errorMessage = null;
    notifyListeners();
  }
}
