import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application_4/core/routes/auth_gate.dart';
import 'package:flutter_application_4/features/auth/domain/entities/user_entity.dart';
import 'package:flutter_application_4/features/auth/domain/repositories/auth_repository.dart';
import 'package:flutter_application_4/features/auth/presentation/controllers/auth_controller.dart';
import 'package:flutter_application_4/features/auth/presentation/pages/login_page.dart';
import 'package:flutter_application_4/features/home/presentation/pages/patient_home_page.dart';

class _HomeAuthRepository extends Fake implements AuthRepository {
  bool loggedOut = false;

  @override
  Stream<String?> get authStateChanges => const Stream.empty();

  @override
  Future<UserEntity?> getCurrentUser() async => const UserEntity(
    id: 'patient-1',
    fullName: 'Nguyễn An',
    email: 'patient@example.com',
    phone: '',
    role: UserRole.patient,
    isActive: true,
  );

  @override
  Future<void> logout() async {
    loggedOut = true;
  }
}

void main() {
  testWidgets('Patient home supports small screens, search and navigation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _HomeAuthRepository();
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AuthController(authRepo: repository),
        child: const MaterialApp(home: AuthGate()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(PatientHomePage), findsOneWidget);
    expect(find.text('Bệnh viện Quốc tế Meridian'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.enterText(find.byType(TextField), 'Đặt khám');
    await tester.pump();
    expect(find.text('Đặt khám', findRichText: false).last, findsOneWidget);
    expect(find.text('Hồ sơ sức khỏe'), findsNothing);
    await tester.tap(find.text('Đặt khám', findRichText: false).last);
    await tester.pumpAndSettle();
    expect(
      find.text('Chức năng đang được hoàn thiện. Vui lòng quay lại sau.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Đã hiểu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thông báo'));
    await tester.pumpAndSettle();
    expect(find.text('Bạn chưa có thông báo mới.'), findsOneWidget);
    await tester.tap(find.text('Chức năng'));
    await tester.pumpAndSettle();
    expect(find.text('Hồ sơ sức khỏe'), findsOneWidget);
    await tester.tap(find.text('Cá nhân'));
    await tester.pumpAndSettle();
    expect(find.text('Nguyễn An'), findsOneWidget);
    expect(find.text('patient@example.com'), findsOneWidget);
    await tester.tap(find.text('Đăng xuất'));
    await tester.pumpAndSettle();
    expect(repository.loggedOut, isTrue);
    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.byType(PatientHomePage), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
