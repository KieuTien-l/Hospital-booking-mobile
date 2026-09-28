import 'dart:async';

import 'package:flutter_application_4/core/entities/user_entity.dart';
import 'package:flutter_application_4/core/network/api_exception.dart';
import 'package:flutter_application_4/features/auth/data/datasources/auth_firestore_rest_datasource.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('AuthFirestoreRestDatasource', () {
    test(
      'uses GET and deserializes a Firestore document into UserModel',
      () async {
        final datasource = AuthFirestoreRestDatasource(
          client: MockClient((request) async {
            expect(request.method, 'GET');
            expect(
              request.url.path,
              '/v1/projects/bookinghospitalapp/databases/(default)/documents/users/user-1',
            );
            expect(request.headers['authorization'], 'Bearer id-token');
            return http.Response(_validProfileDocument, 200);
          }),
        );

        final user = await datasource.getUser(
          userId: 'user-1',
          idToken: 'id-token',
        );

        expect(user.id, 'user-1');
        expect(user.email, 'patient@example.com');
        expect(user.fullName, 'Patient One');
        expect(user.phone, '0900000000');
        expect(user.role, UserRole.patient);
        expect(user.isActive, isTrue);
        expect(user.createdAt, DateTime.parse('2026-09-20T10:00:00Z'));
      },
    );

    test('reports a non-success status code as an HTTP error', () async {
      final datasource = AuthFirestoreRestDatasource(
        client: MockClient((_) async => http.Response('{}', 404)),
      );

      await expectLater(
        datasource.getUser(userId: 'missing', idToken: 'id-token'),
        throwsA(
          isA<ApiException>()
              .having((error) => error.kind, 'kind', ApiFailureKind.http)
              .having((error) => error.statusCode, 'statusCode', 404),
        ),
      );
    });

    test('reports malformed JSON as an invalid response', () async {
      final datasource = AuthFirestoreRestDatasource(
        client: MockClient((_) async => http.Response('{invalid', 200)),
      );

      await expectLater(
        datasource.getUser(userId: 'user-1', idToken: 'id-token'),
        throwsA(
          isA<ApiException>().having(
            (error) => error.kind,
            'kind',
            ApiFailureKind.invalidResponse,
          ),
        ),
      );
    });

    test('reports a client exception as a network error', () async {
      final datasource = AuthFirestoreRestDatasource(
        client: MockClient((_) => throw http.ClientException('offline')),
      );

      await expectLater(
        datasource.getUser(userId: 'user-1', idToken: 'id-token'),
        throwsA(
          isA<ApiException>().having(
            (error) => error.kind,
            'kind',
            ApiFailureKind.network,
          ),
        ),
      );
    });

    test('reports a request that exceeds the timeout', () async {
      final pendingResponse = Completer<http.Response>();
      final datasource = AuthFirestoreRestDatasource(
        timeout: const Duration(milliseconds: 10),
        client: MockClient((_) => pendingResponse.future),
      );

      await expectLater(
        datasource.getUser(userId: 'user-1', idToken: 'id-token'),
        throwsA(
          isA<ApiException>().having(
            (error) => error.kind,
            'kind',
            ApiFailureKind.timeout,
          ),
        ),
      );
    });
  });
}

const _validProfileDocument = '''
{
  "name": "projects/bookinghospitalapp/databases/(default)/documents/users/user-1",
  "fields": {
    "email": {"stringValue": "patient@example.com"},
    "fullName": {"stringValue": "Patient One"},
    "phone": {"stringValue": "0900000000"},
    "role": {"stringValue": "patient"},
    "isActive": {"booleanValue": true},
    "createdAt": {"timestampValue": "2026-09-20T10:00:00Z"}
  }
}
''';
