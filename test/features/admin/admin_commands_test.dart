import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_application_4/features/admin/data/admin_commands.dart';

void main() {
  test('admin gateway sends a verified token and preserves idempotency key without signing in another user', () async {
    final payloads = <Map<String, dynamic>>[];
    final commands = FirebaseAdminCommands(
      endpointOverride: Uri.https('test.example.com', '/adminCommand'),
      tokenProvider: () async => 'test-id-token',
      client: MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer test-id-token');
        final payload = jsonDecode(request.body) as Map<String, dynamic>;
        expect(payload.keys, ['data']);
        payloads.add(payload['data'] as Map<String, dynamic>);
        return http.Response(
          jsonEncode({
            'result': {'id': 'created', 'message': 'OK'},
          }),
          200,
        );
      }),
    );
    final command = {
      'operation': 'createDoctor',
      'requestId': adminRequestId(),
      'values': {'loginEmail': 'doctor@example.com'},
    };
    expect((await commands.execute(command))['id'], 'created');
    await commands.execute(command);
    expect(payloads[0]['requestId'], payloads[1]['requestId']);
    commands.dispose();
  });
  test('missing auth, permission errors and undeployed backend never report success', () async {
    var requests = 0;
    final missing = FirebaseAdminCommands(
      tokenProvider: () async => null,
      client: MockClient((_) async {
        requests++;
        return http.Response('{}', 200);
      }),
    );
    await expectLater(
      missing.execute({}),
      throwsA(isA<AdminCommandException>()),
    );
    expect(requests, 0);
    missing.dispose();
    for (final code in [403, 404]) {
      final commands = FirebaseAdminCommands(
        endpointOverride: Uri.https('test.example.com'),
        tokenProvider: () async => 'token',
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'error': {'message': 'Không có quyền'},
            }),
            code,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ),
        ),
      );
      await expectLater(
        commands.execute({}),
        throwsA(
          isA<AdminCommandException>().having(
            (e) => e.message,
            'message',
            contains(code == 404 ? 'chưa được triển khai' : 'Không có quyền'),
          ),
        ),
      );
      commands.dispose();
    }
  });
  test('uncertain requests and failed invitation keep separate truthful error states', () async {
    final commands = FirebaseAdminCommands(
      endpointOverride: Uri.https('test.example.com'),
      tokenProvider: () async => 'token',
      client: MockClient((_) async => throw http.ClientException('network')),
      passwordSender: (_) async => throw StateError('mail failed'),
    );
    await expectLater(
      commands.execute({'requestId': 'keep-this-key'}),
      throwsA(
        isA<AdminCommandException>().having(
          (e) => e.message,
          'message',
          contains('cùng mã yêu cầu'),
        ),
      ),
    );
    await expectLater(
      commands.sendPasswordSetup('doctor@example.com'),
      throwsA(
        isA<AdminCommandException>().having(
          (e) => e.message,
          'message',
          contains('Tài khoản vẫn được giữ'),
        ),
      ),
    );
    commands.dispose();
  });
}
