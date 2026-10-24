import 'package:flutter/foundation.dart';

import '../../data/repositories/worker_chatbot_repository.dart';
import '../../domain/entities/chat_message.dart';
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

  Future<void> send(String draft) async {
    final text = draft.trim();
    if (text.isEmpty || isSending) return;
    _messages.add(ChatMessage(role: ChatMessageRole.user, text: text));
    await _requestReply();
  }

  Future<void> retry() async {
    if (isSending || _messages.isEmpty || !_messages.last.isUser) return;
    await _requestReply();
  }

  Future<void> _requestReply() async {
    _requestState = ChatbotRequestState.sending;
    _errorMessage = null;
    notifyListeners();
    try {
      final reply = await _repository.sendMessage(
        message: _messages.last.text,
        history: _messages,
      );
      _messages.add(ChatMessage(role: ChatMessageRole.assistant, text: reply));
      _requestState = ChatbotRequestState.success;
    } on ChatbotException catch (error) {
      _errorMessage = error.message;
      _requestState = ChatbotRequestState.error;
    } catch (_) {
      _errorMessage = 'Không thể gửi tin nhắn lúc này. Vui lòng thử lại.';
      _requestState = ChatbotRequestState.error;
    } finally {
      notifyListeners();
    }
  }

  void reset() {
    if (isSending || (_messages.isEmpty && _errorMessage == null)) return;
    _messages.clear();
    _errorMessage = null;
    _requestState = ChatbotRequestState.idle;
    notifyListeners();
  }
}
