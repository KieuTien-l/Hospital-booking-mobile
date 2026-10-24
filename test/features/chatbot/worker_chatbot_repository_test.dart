import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_application_4/features/chatbot/data/repositories/worker_chatbot_repository.dart';
import 'package:flutter_application_4/features/chatbot/domain/entities/chat_message.dart';

void main() {
  const question = 'Tôi đau họng, nên khám chuyên khoa nào?';
  List<ChatMessage> history([String value = question]) => [
    ChatMessage(role: ChatMessageRole.user, text: value),
  ];
  var writes = <Map<String, dynamic>>[];
  var calls = 0;
  ChatIdentity? identity;
  late Future<http.Response> Function(http.Request) respond;
  late WorkerChatbotRepository repository;
  setUp(() {
    writes = [];
    calls = 0;
    identity = const ChatIdentity('user-a', 'firebase-token');
    respond = (_) async => http.Response(
      jsonEncode({'reply': 'Hãy kiểm tra chuyên khoa trong ứng dụng.'}),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
    repository = WorkerChatbotRepository(
      client: MockClient((request) {
        calls++;
        return respond(request);
      }),
      identityProvider: () async => identity,
      persistHistory: (value) async => writes.add(value),
    );
  });

  test('AI-15: authenticated request uses Worker and saves only the owner transcript', () async {
    respond = (request) async {
      expect(request.url.scheme, 'https');
      expect(request.url.path, '/chat');
      expect(request.headers['Authorization'], 'Bearer firebase-token');
      expect(request.body, isNot(contains('OPENAI_API_KEY')));
      expect((jsonDecode(request.body) as Map)['message'], question);
      return http.Response(
        jsonEncode({'reply': 'Câu trả lời'}),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    };
    expect(
      await repository.sendMessage(message: question, history: history()),
      'Câu trả lời',
    );
    expect(writes.single['authUserId'], 'user-a');
    expect(writes.single['userId'], 'user-a');
    expect(writes.single['userMessage'], question);
    expect(writes.single['aiReply'], 'Câu trả lời');
  });
  for (final (index, value) in [
    'Mã OTP của tôi là 123456',
    'Mật khẩu là private',
    'Số thẻ 4111111111111111',
    'Bệnh án của tôi',
    'x' * 2001,
  ].indexed) {
    test(
      'AI-12: rejects private or oversized input before network ($index)',
      () async {
        await expectLater(
          repository.sendMessage(message: value, history: history(value)),
          throwsA(isA<ChatbotException>()),
        );
        expect(calls, 0);
        expect(writes, isEmpty);
      },
    );
  }
  test('AI-12: checks old history before transmission', () async {
    await expectLater(
      repository.sendMessage(
        message: question,
        history: [...history('OTP 123456'), ...history()],
      ),
      throwsA(isA<ChatbotException>()),
    );
    expect(calls, 0);
    expect(writes, isEmpty);
  });
  test('AI-06: signed-out requests cannot use the Worker', () async {
    identity = null;
    await expectLater(
      repository.sendMessage(message: question, history: history()),
      throwsA(isA<ChatbotException>()),
    );
    expect(calls, 0);
    expect(writes, isEmpty);
  });
  test('AI-06: last twelve turns bound the request context', () async {
    respond = (request) async {
      final data = jsonDecode(request.body) as Map;
      expect(data['history'], hasLength(12));
      return http.Response('{"reply":"OK"}', 200);
    };
    await repository.sendMessage(
      message: question,
      history: [
        for (var i = 0; i < 20; i++) ...history('Nội dung $i'),
        ...history(),
      ],
    );
    expect(calls, 1);
  });
  for (final status in [401, 403, 429, 500, 502, 503, 504]) {
    test(
      'AI-12: HTTP $status has safe error text and no transcript write',
      () async {
        respond = (_) async =>
            http.Response('{"error":"PRIVATE_PROVIDER_SECRET"}', status);
        try {
          await repository.sendMessage(message: question, history: history());
          fail('Expected failure');
        } on ChatbotException catch (error) {
          expect(error.message, isNot(contains('PRIVATE_PROVIDER_SECRET')));
        }
        expect(writes, isEmpty);
      },
    );
  }
  for (final (index, body) in [
    'not json',
    '{}',
    '{"reply":""}',
    jsonEncode({'reply': 'x' * 2001}),
  ].indexed) {
    test(
      'AI-12: malformed, empty and oversized replies are rejected ($index)',
      () async {
        respond = (_) async => http.Response(body, 200);
        await expectLater(
          repository.sendMessage(message: question, history: history()),
          throwsA(isA<ChatbotException>()),
        );
        expect(writes, isEmpty);
      },
    );
  }
  test(
    'AI-12: connection failures can be retried without saving failed turns',
    () async {
      respond = (_) async =>
          throw http.ClientException('PRIVATE_NETWORK_DETAIL');
      await expectLater(
        repository.sendMessage(message: question, history: history()),
        throwsA(isA<ChatbotException>()),
      );
      expect(writes, isEmpty);
      respond = (_) async => http.Response('{"reply":"OK"}', 200);
      expect(
        await repository.sendMessage(message: question, history: history()),
        'OK',
      );
      expect(writes, hasLength(1));
    },
  );
  test('AI-12: a timeout does not keep the UI waiting indefinitely', () async {
    repository = WorkerChatbotRepository(
      client: MockClient((_) => Completer<http.Response>().future),
      identityProvider: () async => identity,
      persistHistory: (value) async => writes.add(value),
      requestTimeout: const Duration(milliseconds: 5),
    );
    await expectLater(
      repository.sendMessage(message: question, history: history()),
      throwsA(isA<ChatbotException>()),
    );
    expect(writes, isEmpty);
  });
  test('AI-12: switching accounts while waiting discards the response and transcript', () async {
    respond = (_) async {
      identity = const ChatIdentity('user-b', 'other-token');
      return http.Response('{"reply":"private reply for a"}', 200);
    };
    await expectLater(
      repository.sendMessage(message: question, history: history()),
      throwsA(isA<ChatbotException>()),
    );
    expect(writes, isEmpty);
  });
  test('AI-12: failed history writes do not discard a valid reply', () async {
    repository = WorkerChatbotRepository(
      client: MockClient((_) async => http.Response('{"reply":"OK"}', 200)),
      identityProvider: () async => identity,
      persistHistory: (_) async => throw StateError('offline'),
    );
    expect(
      await repository.sendMessage(message: question, history: history()),
      'OK',
    );
  });
  test(
    'AI-06: insecure endpoint is rejected before sending the token',
    () async {
      repository = WorkerChatbotRepository(
        client: MockClient((request) {
          calls++;
          return respond(request);
        }),
        identityProvider: () async => identity,
        endpoint: 'http://worker.example',
      );
      await expectLater(
        repository.sendMessage(message: question, history: history()),
        throwsA(isA<ChatbotException>()),
      );
      expect(calls, 0);
    },
  );
}
