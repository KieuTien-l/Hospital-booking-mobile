import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_4/features/auth/data/datasources/auth_firebase_datasource.dart';
import 'package:flutter_application_4/features/auth/domain/exceptions/auth_exception.dart';

class _FailingAuth extends Fake implements FirebaseAuth {
  _FailingAuth(this.code);
  final String code;

  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    throw FirebaseAuthException(code: code);
  }
}

class _UnusedFirestore extends Fake implements FirebaseFirestore {}

void main() {
  final messages = {
    'network-request-failed': 'Không thể kết nối đến máy chủ đăng nhập. Vui lòng kiểm tra kết nối Internet rồi thử lại.',
    'too-many-requests':
        'Bạn đã thử đăng nhập quá nhiều lần. Vui lòng chờ một lúc rồi thử lại.',
    'invalid-credential': 'The email address or password is incorrect.',
    'user-disabled': 'This account has been disabled.',
    'unknown': 'Unable to sign in. Please try again.',
  };
  for (final entry in messages.entries) {
    test('Login reports ${entry.key} without querying the profile', () async {
      final datasource = AuthFirebaseDatasource(
        auth: _FailingAuth(entry.key),
        firestore: _UnusedFirestore(),
      );
      await expectLater(
        datasource.login('test@example.com', 'test-password'),
        throwsA(
          isA<AuthException>().having(
            (error) => error.message,
            'message',
            entry.value,
          ),
        ),
      );
    });
  }
}
