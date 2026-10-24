import '../entities/chat_message.dart';

abstract class ChatbotRepository {
  Future<String> sendMessage({
    required String message,
    required List<ChatMessage> history,
  });
}
