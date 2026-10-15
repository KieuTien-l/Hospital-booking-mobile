import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application_4/core/themes/app_theme.dart';
import 'package:flutter_application_4/core/routes/auth_gate.dart';
import 'package:flutter_application_4/features/auth/domain/entities/user_entity.dart';
import 'package:flutter_application_4/features/auth/domain/repositories/auth_repository.dart';
import 'package:flutter_application_4/features/auth/presentation/controllers/auth_controller.dart';
import 'package:flutter_application_4/features/auth/presentation/pages/login_page.dart';
import 'package:flutter_application_4/features/appointments/domain/entities/appointment.dart';
import 'package:flutter_application_4/features/doctors/domain/entities/work_schedule.dart';
import 'package:flutter_application_4/features/home/presentation/pages/doctor_home_page.dart';
import 'package:flutter_application_4/features/home/presentation/widgets/doctor_dashboard_stat_card.dart';
import 'package:flutter_application_4/features/home/presentation/widgets/doctor_today_appointments_section.dart';

class _AuthRepository implements AuthRepository {
  _AuthRepository(this.user);
  UserEntity? user;
  int logoutCalls = 0;
  final events = StreamController<String?>.broadcast();
  @override
  Stream<String?> get authStateChanges => events.stream;
  @override
  Future<UserEntity?> getCurrentUser() async => user;
  @override
  Future<UserRole?> getUserRole() async => user?.role;
  @override
  Future<void> logout() async {
    logoutCalls++;
    user = null;
    events.add(null);
  }

  @override
  Future<UserEntity> login({
    required String email,
    required String password,
  }) async => user!;
  @override
  Future<UserEntity> register({
    required String email,
    required String password,
    required String fullName,
    required String phone,
  }) async => throw UnimplementedError();

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {}
}

UserEntity _doctor(String name) => UserEntity(
  id: 'doctor-account',
  email: '',
  fullName: name,
  phone: '',
  role: UserRole.doctor,
  isActive: true,
);

Future<_AuthRepository> _pumpDashboard(
  WidgetTester tester,
  UserEntity? user, {
  bool gate = false,
  double textScale = 1,
}) async {
  final repository = _AuthRepository(user);
  final auth = AuthController(authRepo: repository);
  addTearDown(auth.dispose);
  addTearDown(repository.events.close);
  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: auth,
      child: RepaintBoundary(
        key: const ValueKey('dashboard-preview'),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: gate ? const AuthGate() : const DoctorHomePage(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repository;
}

void main() {
  testWidgets('Dashboard preview with actual font and mobile viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    final font = FontLoader('BeVietnamPro')
      ..addFont(
        rootBundle.load('assets/fonts/be_vietnam_pro/BeVietnamPro-Regular.ttf'),
      );
    await font.load();
    await _pumpDashboard(tester, _doctor(''));
    expect(tester.takeException(), isNull);
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('dashboard-preview')),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('.dart_tool/doctor_dashboard_preview.png');
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
    await tester.tap(find.text('Báo cáo'));
    await tester.pumpAndSettle();
    for (final part in ['top', 'bottom']) {
      if (part == 'bottom') {
        await tester.ensureVisible(find.text('Gửi báo cáo cho Admin'));
        await tester.pumpAndSettle();
      }
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('.dart_tool/doctor_reports_preview_$part.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
    await tester.tap(find.text('Cá nhân'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File('.dart_tool/doctor_profile_preview.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Uses authenticated name and shows unavailable data without counts',
    (tester) async {
      await _pumpDashboard(tester, _doctor('  Nguyễn An  '));
      expect(find.text('Xin chào, Bác sĩ Nguyễn An!'), findsOneWidget);
      expect(find.byType(DoctorDashboardStatCard), findsNWidgets(3));
      expect(find.text('—'), findsNWidgets(3));
      await tester.ensureVisible(find.byType(DoctorTodayAppointmentsSection));
      expect(find.text('Chưa có dữ liệu ca làm để hiển thị'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final name in <String?>[null, '', '   ']) {
    testWidgets('Generic greeting for missing name: $name', (tester) async {
      await _pumpDashboard(tester, name == null ? null : _doctor(name));
      expect(find.text('Xin chào, Bác sĩ!'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final width in [320.0, 390.0, 800.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('No overflow at width $width and text scale $scale', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await _pumpDashboard(
          tester,
          _doctor('Nguyễn Thị Minh Anh Phương'),
          textScale: scale,
        );
        await tester.ensureVisible(find.byType(DoctorTodayAppointmentsSection));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        for (final tab in ['Báo cáo', 'Cá nhân']) {
          await tester.tap(find.text(tab));
          await tester.pumpAndSettle();
          await tester.drag(
            find.byType(SingleChildScrollView).hitTestable().first,
            const Offset(0, -1600),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
      });
    }
  }

  testWidgets('Logout button calls AuthController and returns to Login', (
    tester,
  ) async {
    final repository = await _pumpDashboard(
      tester,
      _doctor('Nguyễn An'),
      gate: true,
    );
    await tester.tap(find.text('Cá nhân'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Tài khoản'));
    await tester.tap(find.text('Tài khoản'));
    await tester.pumpAndSettle();
    final logout = find.widgetWithText(OutlinedButton, 'Đăng xuất');
    await tester.ensureVisible(logout);
    await tester.tap(logout);
    await tester.pumpAndSettle();
    expect(repository.logoutCalls, 1);
    expect(find.byType(LoginPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Date picker updates selected day and tabs preserve the selection',
    (tester) async {
      await _pumpDashboard(tester, _doctor('Nguyễn An'));
      await tester.tap(find.byKey(const ValueKey('doctor-date-picker')));
      await tester.pumpAndSettle();
      final initial = tester
          .widget<DatePickerDialog>(find.byType(DatePickerDialog))
          .initialDate!;
      final day = initial.day == 15 ? 16 : 15;
      await tester.tap(
        find.descendant(
          of: find.byType(DatePickerDialog),
          matching: find.text('$day'),
        ),
      );
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      final label =
          '${day.toString().padLeft(2, '0')}/${initial.month.toString().padLeft(2, '0')}/${initial.year}';
      expect(find.text(label), findsOneWidget);
      await tester.tap(find.text('Báo cáo'));
      await tester.pumpAndSettle();
      expect(find.text('Ngày xảy ra: $label'), findsOneWidget);
      await tester.tap(find.text('Trang chủ'));
      await tester.pumpAndSettle();
      expect(find.text(label), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Day strip selects date and bottom navigation stays fixed while scrolling',
    (tester) async {
      await _pumpDashboard(tester, _doctor('Nguyễn An'));
      final selected = tester
          .widget<DoctorTodayAppointmentsSection>(
            find.byType(DoctorTodayAppointmentsSection),
          )
          .selectedDate!;
      final next = selected.add(const Duration(days: 1));
      final label =
          '${next.day.toString().padLeft(2, '0')}/${next.month.toString().padLeft(2, '0')}/${next.year}';
      await tester.tap(find.byTooltip('Chọn ngày $label'));
      await tester.pumpAndSettle();
      expect(find.text(label), findsOneWidget);
      expect(
        tester
            .widget<DoctorTodayAppointmentsSection>(
              find.byType(DoctorTodayAppointmentsSection),
            )
            .selectedDate,
        next,
      );
      final navigationBounds = tester.getRect(find.byType(NavigationBar));
      await tester.ensureVisible(find.text('Trạng thái dữ liệu'));
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byType(NavigationBar)), navigationBounds);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Report validates UI draft, preserves text and never enables sending',
    (tester) async {
      await _pumpDashboard(tester, _doctor('Nguyễn An'));
      await tester.tap(find.text('Báo cáo'));
      await tester.pumpAndSettle();
      expect(find.text('Thông tin báo cáo'), findsOneWidget);
      expect(
        find.text('Admin phê duyệt trước khi thay đổi lịch'),
        findsNothing,
      );
      expect(find.byTooltip('Đăng xuất'), findsNothing);
      await tester.ensureVisible(find.text('Kiểm tra biểu mẫu'));
      await tester.tap(find.text('Kiểm tra biểu mẫu'));
      await tester.pumpAndSettle();
      expect(find.text('Vui lòng chọn loại vấn đề.'), findsOneWidget);
      expect(find.text('Vui lòng nhập lý do.'), findsOneWidget);
      expect(find.text('Vui lòng nhập mô tả chi tiết.'), findsOneWidget);
      final reason = find.byKey(const ValueKey('doctor-report-reason'));
      await tester.ensureVisible(reason);
      await tester.enterText(reason, 'Nội dung nhập để kiểm thử');
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Báo cáo'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextFormField>(reason).controller?.text ??
            tester.state<FormFieldState<String>>(reason).value,
        'Nội dung nhập để kiểm thử',
      );
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Gửi báo cáo cho Admin'),
            )
            .onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Profile uses auth, keeps fields read-only and previews default avatar',
    (tester) async {
      await _pumpDashboard(
        tester,
        const UserEntity(
          id: 'doctor-account',
          email: 'test@example.com',
          fullName: 'Nguyễn An',
          phone: '0901234567',
          role: UserRole.doctor,
          isActive: true,
        ),
      );
      await tester.tap(find.text('Cá nhân'));
      await tester.pumpAndSettle();
      expect(find.text('test@example.com'), findsNothing);
      expect(find.text('0901234567'), findsNothing);
      await tester.ensureVisible(find.text('Thông tin cá nhân'));
      await tester.tap(find.text('Thông tin cá nhân'));
      await tester.pumpAndSettle();
      expect(find.text('test@example.com'), findsOneWidget);
      expect(find.text('0901234567'), findsOneWidget);
      for (final field in tester.widgetList<TextField>(
        find.byType(TextField),
      )) {
        expect(field.readOnly, isTrue);
      }
      await tester.ensureVisible(find.text('Lưu thay đổi'));
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Lưu thay đổi'),
            )
            .onPressed,
        isNull,
      );
      await tester.ensureVisible(find.text('Thông tin cá nhân'));
      await tester.tap(find.text('Thông tin cá nhân'));
      await tester.pumpAndSettle();
      expect(find.text('0901234567'), findsNothing);
      await tester.ensureVisible(find.text('Ảnh đại diện'));
      await tester.tap(find.text('Ảnh đại diện'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Chọn ảnh'),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.text('Xem ảnh'));
      await tester.pumpAndSettle();
      expect(find.text('Đang sử dụng ảnh đại diện mặc định.'), findsOneWidget);
      await tester.tap(find.text('Đóng'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Professional accordion matches Patient doctor detail sections without demo values',
    (tester) async {
      await _pumpDashboard(tester, _doctor('Nguyễn An'));
      await tester.tap(find.text('Cá nhân'));
      await tester.pumpAndSettle();
      expect(find.text('Quá trình đào tạo'), findsNothing);
      await tester.ensureVisible(find.text('Thông tin chuyên môn'));
      await tester.tap(find.text('Thông tin chuyên môn'));
      await tester.pumpAndSettle();
      for (final title in [
        'Lịch khám bệnh',
        'Quá trình đào tạo',
        'Quá trình công tác',
        'Hiệp hội chuyên môn',
        'Công trình nghiên cứu',
      ]) {
        expect(find.text(title), findsOneWidget);
      }
      await tester.ensureVisible(find.text('Quá trình công tác'));
      await tester.tap(find.text('Quá trình công tác'));
      await tester.pumpAndSettle();
      expect(find.text('Kinh nghiệm khám, chữa bệnh'), findsOneWidget);
      expect(find.text('Kinh nghiệm giảng dạy'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Verified schedules show only the selected date and real appointment counts',
    (tester) async {
      final date = DateTime(2026, 10, 14);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: DoctorTodayAppointmentsSection(
              selectedDate: date,
              state: DoctorAppointmentsDisplayState.data,
              schedules: [
                WorkSchedule(
                  id: 'schedule-test',
                  doctorId: 'doctor-test',
                  workDate: date,
                  startTime: '08:00',
                  endTime: '12:00',
                ),
                WorkSchedule(
                  id: 'other-day',
                  doctorId: 'doctor-test',
                  workDate: DateTime(2026, 10, 15),
                ),
              ],
              appointments: [
                Appointment(
                  id: 'pending',
                  patientId: 'patient-1',
                  doctorId: 'doctor-test',
                  workScheduleId: 'schedule-test',
                  timeSlotId: 'slot-pending',
                  appointmentDate: date,
                  peopleCount: 2,
                  status: AppointmentStatus.pending,
                ),
                Appointment(
                  id: 'completed',
                  patientId: 'patient-2',
                  doctorId: 'doctor-test',
                  workScheduleId: 'schedule-test',
                  timeSlotId: 'slot-completed',
                  appointmentDate: date,
                  status: AppointmentStatus.completed,
                ),
                Appointment(
                  id: 'cancelled',
                  patientId: 'patient-3',
                  doctorId: 'doctor-test',
                  workScheduleId: 'schedule-test',
                  timeSlotId: 'slot-cancelled',
                  appointmentDate: date,
                  status: AppointmentStatus.cancelled,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.tap(find.text('Lịch schedule-test'));
      await tester.pumpAndSettle();
      expect(find.text('Lịch other-day'), findsNothing);
      expect(find.text('Chi tiết lịch làm việc'), findsOneWidget);
      expect(find.text('3 / 1 / 2'), findsOneWidget);
      expect(find.text('Bệnh nhân đã khám: 1'), findsOneWidget);
      expect(find.text('Danh sách bệnh nhân'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final state in DoctorAppointmentsDisplayState.values) {
    testWidgets('Appointment section renders $state without action buttons', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: DoctorTodayAppointmentsSection(state: state),
            ),
          ),
        ),
      );
      await tester.pump();
      if (state == DoctorAppointmentsDisplayState.loading) {
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      } else if (state == DoctorAppointmentsDisplayState.error) {
        expect(find.text('Không thể tải lịch khám'), findsOneWidget);
      } else {
        expect(
          find.text('Chưa có dữ liệu lịch khám để hiển thị'),
          findsOneWidget,
        );
      }
      expect(find.byType(TextButton), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
