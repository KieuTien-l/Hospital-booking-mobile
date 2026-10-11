import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application_4/features/auth/domain/entities/user_entity.dart';
import 'package:flutter_application_4/features/auth/domain/repositories/auth_repository.dart';
import 'package:flutter_application_4/features/auth/presentation/controllers/auth_controller.dart';
import 'package:flutter_application_4/features/auth/presentation/pages/forgot_password_page.dart';

class _PasswordResetRepository extends Fake implements AuthRepository {
  String? requestedEmail;

  @override
  Stream<String?> get authStateChanges => const Stream.empty();

  @override
  Future<UserEntity?> getCurrentUser() async => null;

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {
    requestedEmail = email;
  }
}

void main() {
  testWidgets('Forgot password sends the entered email through AuthController', (
    tester,
  ) async {
    final repository = _PasswordResetRepository();
    final controller = AuthController(authRepo: repository);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: controller,
        child: const MaterialApp(home: ForgotPasswordPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), 'patient@example.com');
    await tester.tap(find.text('Gửi liên kết đặt lại'));
    await tester.pumpAndSettle();

    expect(repository.requestedEmail, 'patient@example.com');
    expect(find.textContaining('liên kết đặt lại mật khẩu đã được gửi'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
