enum ChatMessageRole { user, assistant }

class ChatMessage {
  const ChatMessage({required this.role, required this.text});

  final ChatMessageRole role;
  final String text;

  bool get isUser => role == ChatMessageRole.user;

  Map<String, String> toRequestJson() => {
    'role': isUser ? 'user' : 'assistant',
    'text': text,
  };
}
