import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_4/features/chatbot/data/repositories/worker_chatbot_repository.dart';
import 'package:flutter_application_4/features/chatbot/domain/entities/chat_message.dart';
import 'package:flutter_application_4/features/chatbot/domain/repositories/chatbot_repository.dart';
import 'package:flutter_application_4/features/chatbot/presentation/controllers/chatbot_controller.dart';

void main() {
  test(
    'AI-12: private input never enters the conversation or repository',
    () async {
      final repository = _ChatbotRepository(reply: 'OK');
      final controller = ChatbotController(repository);
      await controller.send('Mã OTP là 123456');
      expect(controller.messages, isEmpty);
      expect(repository.callCount, 0);
      expect(controller.errorMessage, contains('quyền riêng tư'));
      await controller.send('Cách đặt lịch khám?');
      expect(controller.messages, hasLength(2));
      expect(repository.callCount, 1);
    },
  );
  test('AI-15: duplicate sends are blocked and retry does not duplicate the question', () async {
    final pending = Completer<String>();
    final repository = _PendingRepository(pending);
    final controller = ChatbotController(repository);
    final send = controller.send('Đặt lịch khám');
    await controller.send('Gửi trùng');
    expect(repository.calls, 1);
    expect(controller.isSending, isTrue);
    pending.complete('OK');
    await send;
    expect(controller.messages, hasLength(2));
  });
  test('AI-12: disposed controller ignores late network responses', () async {
    final pending = Completer<String>();
    final controller = ChatbotController(_PendingRepository(pending));
    final send = controller.send('Đặt lịch khám');
    controller.dispose();
    pending.complete('Private late reply');
    await send;
    expect(controller.messages, isEmpty);
  });
  test(
    'AI-12: account switch clears messages and invalidates pending replies',
    () async {
      final pending = Completer<String>();
      final controller = ChatbotController(_PendingRepository(pending));
      controller.bindUser('a');
      final send = controller.send('Đặt lịch khám');
      controller.bindUser(null);
      controller.bindUser('b');
      pending.complete('Private reply for a');
      await send;
      expect(controller.messages, isEmpty);
      expect(controller.isSending, isFalse);
    },
  );
  test(
    'AI-15: new question replaces a failed turn in outgoing context',
    () async {
      final repository = _ChatbotRepository(
        error: const ChatbotException('offline'),
      );
      final controller = ChatbotController(repository);
      await controller.send('Câu hỏi đã lỗi');
      repository
        ..error = null
        ..reply = 'OK';
      await controller.send('Câu hỏi mới');
      expect(repository.requestedHistory.single.text, 'Câu hỏi mới');
      expect(controller.messages, hasLength(2));
    },
  );
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

class _PendingRepository implements ChatbotRepository {
  _PendingRepository(this.pending);
  final Completer<String> pending;
  int calls = 0;
  @override
  Future<String> sendMessage({
    required String message,
    required List<ChatMessage> history,
  }) {
    calls++;
    return pending.future;
  }
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
