import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application_4/features/appointments/presentation/pages/select_appointment_date_page.dart';
import 'package:flutter_application_4/core/routes/auth_gate.dart';
import 'package:flutter_application_4/features/auth/domain/entities/user_entity.dart';
import 'package:flutter_application_4/features/auth/domain/repositories/auth_repository.dart';
import 'package:flutter_application_4/features/auth/presentation/controllers/auth_controller.dart';
import 'package:flutter_application_4/features/auth/presentation/pages/login_page.dart';
import 'package:flutter_application_4/features/home/presentation/pages/patient_home_page.dart';
import 'package:flutter_application_4/features/specialties/domain/entities/specialty.dart';
import 'package:flutter_application_4/features/specialties/domain/repositories/specialty_repository.dart';
import 'package:flutter_application_4/features/specialties/presentation/controllers/specialty_controller.dart';

class _HomeSpecialtyRepository implements SpecialtyRepository {
  @override
  Stream<List<Specialty>> watchSpecialties() => Stream.value(const [
    Specialty(id: 'skin', name: 'Da liễu', description: '', isActive: true),
  ]);
}

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
  testWidgets('Health profiles open from Home and Back returns to Home', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AuthController(authRepo: _HomeAuthRepository()),
        child: const MaterialApp(home: PatientHomePage()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hồ sơ\nsức khỏe'));
    await tester.pumpAndSettle();
    expect(find.text('Hồ sơ người bệnh'), findsOneWidget);
    await tester.tap(find.text('NGUYỄN VĂN AN'));
    await tester.pumpAndSettle();
    expect(find.text('Chọn chuyên khoa'), findsNothing);
    expect(find.text('Chọn chức năng'), findsOneWidget);
    await tester.tap(find.byTooltip('Đóng'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      0,
    );
    expect(find.text('Hồ sơ\nsức khỏe'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Profile uses auth data and existing navigation and logout', (
    tester,
  ) async {
    final repository = _HomeAuthRepository();
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AuthController(authRepo: repository),
        child: const MaterialApp(home: AuthGate()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cá nhân'));
    await tester.pumpAndSettle();
    expect(find.text('Nguyễn An'), findsOneWidget);
    expect(find.text('patient@example.com'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      3,
    );
    await tester.tap(find.text('Thông tin bệnh nhân'));
    await tester.pumpAndSettle();
    expect(
      find.text('Chức năng đang được hoàn thiện. Vui lòng quay lại sau.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Đã hiểu'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Đăng xuất'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đăng xuất'));
    await tester.pumpAndSettle();
    expect(repository.loggedOut, isTrue);
    expect(find.byType(LoginPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Functions tab shares navigation and Home placeholder actions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => AuthController(authRepo: _HomeAuthRepository()),
          ),
          ChangeNotifierProvider(
            create: (_) => SpecialtyController(_HomeSpecialtyRepository()),
          ),
        ],
        child: const MaterialApp(home: PatientHomePage()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithIcon(NavigationDestination, Icons.layers_outlined),
    );
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      2,
    );
    expect(find.text('Tiện ích khám bệnh'), findsOneWidget);
    expect(find.text('Hỗ trợ & Tiện ích'), findsOneWidget);
    await tester.tap(find.text('Đặt khám'));
    await tester.pumpAndSettle();
    expect(find.text('Chọn hồ sơ'), findsOneWidget);
    await tester.tap(find.text('NGUYỄN MINH AN'));
    await tester.pumpAndSettle();
    expect(find.text('Chọn chuyên khoa'), findsOneWidget);
    await tester.tap(find.text('DA LIỄU'));
    await tester.pumpAndSettle();
    expect(find.byType(SelectAppointmentDatePage), findsOneWidget);
    expect(
      tester
          .widget<SelectAppointmentDatePage>(
            find.byType(SelectAppointmentDatePage),
          )
          .specialty
          .id,
      'skin',
    );
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Chọn chuyên khoa'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Chọn hồ sơ'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      2,
    );
    await tester.tap(find.text('Đặt khám'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.text('NGUYỄN MINH AN'));
      await tester.pump();
      await Future<void>.delayed(Duration.zero);
    });
    await tester.pumpAndSettle();
    await tester.tap(find.text('DA LIỄU'));
    await tester.pumpAndSettle();
    expect(find.byType(SelectAppointmentDatePage), findsOneWidget);
    await tester.tap(find.byTooltip('Về trang chủ'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      0,
    );
    expect(find.byTooltip('Tìm kiếm'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Patient home supports small screens, search and navigation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _HomeAuthRepository();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => AuthController(authRepo: repository),
          ),
          ChangeNotifierProvider(
            create: (_) => SpecialtyController(_HomeSpecialtyRepository()),
          ),
        ],
        child: const MaterialApp(home: AuthGate()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(PatientHomePage), findsOneWidget);
    expect(
      find.text('Bệnh viện Quốc tế Meridian', findRichText: true),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Tìm kiếm'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Đặt khám');
    await tester.pump();
    expect(find.text('Đặt khám', findRichText: false).last, findsOneWidget);
    expect(find.text('Hồ sơ sức khỏe'), findsNothing);
    await tester.tap(find.text('Đặt khám', findRichText: false).last);
    await tester.pumpAndSettle();
    expect(find.text('Chọn hồ sơ'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thông báo'));
    await tester.pumpAndSettle();
    expect(find.text('LỊCH KHÁM ĐÃ ĐƯỢC XÁC NHẬN'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    await tester.tap(find.text('Chưa đọc'));
    await tester.pumpAndSettle();
    expect(find.text('CHÀO MỪNG BẠN ĐẾN VỚI HEALWAY'), findsNothing);
    await tester.tap(find.text('Đọc tất cả'));
    await tester.pumpAndSettle();
    expect(find.text('CHƯA CÓ THÔNG BÁO'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Tất cả'));
    await tester.pumpAndSettle();
    expect(find.text('LỊCH KHÁM ĐÃ ĐƯỢC XÁC NHẬN'), findsOneWidget);
    await tester.tap(find.text('Chức năng'));
    await tester.pumpAndSettle();
    expect(find.text('Hồ sơ sức khỏe'), findsOneWidget);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      2,
    );
    await tester.tap(find.text('Thông báo').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chưa đọc'));
    await tester.pumpAndSettle();
    expect(find.text('CHƯA CÓ THÔNG BÁO'), findsOneWidget);
    await tester.tap(find.text('Cá nhân'));
    await tester.pumpAndSettle();
    expect(find.text('Nguyễn An'), findsOneWidget);
    expect(find.text('patient@example.com'), findsOneWidget);
    await tester.ensureVisible(find.text('Đăng xuất'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đăng xuất'));
    await tester.pumpAndSettle();
    expect(repository.loggedOut, isTrue);
    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.byType(PatientHomePage), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
