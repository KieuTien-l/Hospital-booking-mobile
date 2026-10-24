import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_4/features/chatbot/data/repositories/worker_chatbot_repository.dart';
import 'package:flutter_application_4/features/chatbot/domain/entities/chat_message.dart';
import 'package:flutter_application_4/features/chatbot/domain/repositories/chatbot_repository.dart';
import 'package:flutter_application_4/features/chatbot/presentation/controllers/chatbot_controller.dart';

void main() {
  group('ChatbotController', () {
    test(
      'exposes a successful send lifecycle and response for the UI',
      () async {
        final repository = _ChatbotRepository(
          reply: 'Bạn có thể đặt lịch ở mục Đặt khám.',
        );
        final controller = ChatbotController(repository);

        expect(controller.requestState, ChatbotRequestState.idle);
        await controller.send('Hướng dẫn đặt lịch khám');

        expect(repository.requestedMessage, 'Hướng dẫn đặt lịch khám');
        expect(repository.requestedHistory.single.isUser, isTrue);
        expect(controller.requestState, ChatbotRequestState.success);
        expect(controller.errorMessage, isNull);
        expect(controller.messages, hasLength(2));
        expect(
          controller.messages.last.text,
          'Bạn có thể đặt lịch ở mục Đặt khám.',
        );
      },
    );

    test('exposes an error and can retry the same user message', () async {
      final repository = _ChatbotRepository(
        error: const ChatbotException('Dịch vụ bận.'),
      );
      final controller = ChatbotController(repository);

      await controller.send('Tôi muốn xem lịch hẹn');

      expect(controller.requestState, ChatbotRequestState.error);
      expect(controller.errorMessage, 'Dịch vụ bận.');
      expect(controller.messages, hasLength(1));

      repository
        ..error = null
        ..reply = 'Bạn vào mục Lịch đặt khám để xem lịch hẹn.';
      await controller.retry();

      expect(controller.requestState, ChatbotRequestState.success);
      expect(controller.errorMessage, isNull);
      expect(controller.messages, hasLength(2));
      expect(repository.callCount, 2);
    });
  });
}

class _ChatbotRepository implements ChatbotRepository {
  _ChatbotRepository({this.reply, this.error});

  String? reply;
  Object? error;
  String? requestedMessage;
  List<ChatMessage> requestedHistory = const [];
  int callCount = 0;

  @override
  Future<String> sendMessage({
    required String message,
    required List<ChatMessage> history,
  }) async {
    callCount++;
    requestedMessage = message;
    requestedHistory = List.of(history);
    if (error != null) throw error!;
    return reply!;
  }
}
