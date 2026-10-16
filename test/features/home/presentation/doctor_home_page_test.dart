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
import 'package:flutter_application_4/features/home/presentation/pages/doctor_home_page.dart';
import 'package:flutter_application_4/features/home/presentation/widgets/doctor_dashboard_stat_card.dart';
import 'package:flutter_application_4/features/home/presentation/widgets/doctor_today_appointments_section.dart';
import 'package:flutter_application_4/features/doctors/domain/entities/work_schedule.dart';
import 'package:flutter_application_4/features/doctors/domain/entities/time_slot.dart';
import 'package:flutter_application_4/core/themes/app_colors.dart';
import 'package:flutter_application_4/features/home/presentation/models/doctor_home_demo_data.dart';

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
  bool showDemoData = true,
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
          home: gate
              ? const AuthGate()
              : DoctorHomePage(showDemoData: showDemoData),
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
      await _pumpDashboard(
        tester,
        _doctor('  Nguyễn An  '),
        showDemoData: false,
      );
      expect(find.text('Xin chào, Bác sĩ Nguyễn An!'), findsOneWidget);
      expect(find.byType(DoctorDashboardStatCard), findsNWidgets(3));
      expect(find.text('—'), findsNWidgets(3));
      await tester.ensureVisible(find.byType(DoctorTodayAppointmentsSection));
      expect(find.text('Chưa có dữ liệu ca làm để hiển thị'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Sample schedules filter by date and show matching totals and details',
    (tester) async {
      await _pumpDashboard(tester, _doctor('Nguyễn An'));
      final section = tester.widget<DoctorTodayAppointmentsSection>(
        find.byType(DoctorTodayAppointmentsSection),
      );
      final today = section.selectedDate!;
      List<int?> totals() => tester
          .widgetList<DoctorDashboardStatCard>(
            find.byType(DoctorDashboardStatCard),
          )
          .map((card) => card.value)
          .toList();
      final todayBooked = today.weekday == DateTime.sunday
          ? 0
          : today.weekday == DateTime.saturday
          ? 12
          : 20;
      expect(totals(), [
        todayBooked,
        todayBooked == 0 ? 0 : 7,
        todayBooked == 0 ? 0 : todayBooked - 7,
      ]);
      if (today.weekday != DateTime.sunday) {
        expect(
          find.byKey(const ValueKey('doctor-slot-DEMO-2-SANG-SLOT-0')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('doctor-slot-DEMO-3-SANG-SLOT-0')),
          findsNothing,
        );
        final details = find.byKey(
          const ValueKey('doctor-slot-DEMO-2-SANG-SLOT-0'),
        );
        await tester.ensureVisible(details);
        await tester.tap(details);
        await tester.pumpAndSettle();
        expect(find.text('Chi tiết ca khám'), findsOneWidget);
        expect(find.text('Đã đặt: 3 / 3 chỗ'), findsOneWidget);
        expect(find.text('Nguyễn Minh Anh'), findsOneWidget);
        expect(find.text('Trần Quốc Bảo'), findsOneWidget);
        expect(find.text('Lê Hoàng Phúc'), findsOneWidget);
        expect(find.text('Phạm Ngọc Mai'), findsNothing);
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        final emptySlot = find.byKey(
          const ValueKey('doctor-slot-DEMO-2-SANG-SLOT-4'),
        );
        await tester.ensureVisible(emptySlot);
        await tester.tap(emptySlot);
        await tester.pumpAndSettle();
        expect(find.text('10:30 - 11:30'), findsOneWidget);
        expect(find.text('Chưa có bệnh nhân đặt ca này'), findsOneWidget);
        expect(find.text('Nguyễn Minh Anh'), findsNothing);
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        if (today.weekday != DateTime.saturday) {
          final afternoonSlot = find.byKey(
            const ValueKey('doctor-slot-DEMO-2-CHIEU-SLOT-0'),
          );
          await tester.ensureVisible(afternoonSlot);
          await tester.tap(afternoonSlot);
          await tester.pumpAndSettle();
          expect(find.text('13:00 - 14:00'), findsOneWidget);
          expect(find.text('Đã đặt: 2 / 4 chỗ'), findsOneWidget);
          expect(find.text('Còn chỗ'), findsOneWidget);
          expect(find.text('Nguyễn Minh Anh'), findsOneWidget);
          expect(find.text('Trần Quốc Bảo'), findsOneWidget);
          expect(find.text('Lê Hoàng Phúc'), findsNothing);
          await tester.tap(find.byType(BackButton));
          await tester.pumpAndSettle();
        }
        expect(
          tester
              .widget<DoctorTodayAppointmentsSection>(
                find.byType(DoctorTodayAppointmentsSection),
              )
              .selectedDate,
          today,
        );
      }
      await tester.ensureVisible(
        find.byKey(const ValueKey('doctor-date-picker')),
      );
      final tomorrow = DateTime(today.year, today.month, today.day + 1);
      String label(DateTime date) =>
          '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
      await tester.tap(find.byTooltip('Chọn ngày ${label(tomorrow)}'));
      await tester.pumpAndSettle();
      final tomorrowBooked = tomorrow.weekday == DateTime.sunday
          ? 0
          : tomorrow.weekday == DateTime.saturday
          ? 12
          : 20;
      expect(totals(), [tomorrowBooked, 0, tomorrowBooked]);
      expect(
        find.byKey(const ValueKey('doctor-slot-DEMO-2-SANG-SLOT-0')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('doctor-slot-DEMO-3-SANG-SLOT-0')),
        tomorrow.weekday == DateTime.sunday ? findsNothing : findsOneWidget,
      );
      final emptyDate = DateTime(today.year, today.month, today.day - 2);
      await tester.tap(find.byTooltip('Chọn ngày ${label(emptyDate)}'));
      await tester.pumpAndSettle();
      final previousBooked = emptyDate.weekday == DateTime.sunday
          ? 0
          : emptyDate.weekday == DateTime.saturday
          ? 12
          : 20;
      expect(totals(), [previousBooked, previousBooked, 0]);
      if (emptyDate.weekday == DateTime.sunday) {
        expect(find.text('Chủ nhật không có ca khám'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Home date picker applies weekend rules outside the initial demo range',
    (tester) async {
      await _pumpDashboard(tester, _doctor('Nguyễn An'));
      final today = tester
          .widget<DoctorTodayAppointmentsSection>(
            find.byType(DoctorTodayAppointmentsSection),
          )
          .selectedDate!;
      final saturday = DateTime(
        today.year,
        today.month,
        today.day + 14 + (DateTime.saturday - today.weekday + 7) % 7,
      );
      for (var offset = 0; offset < 3; offset++) {
        final date = DateTime(
          saturday.year,
          saturday.month,
          saturday.day + offset,
        );
        final picker = find.byKey(const ValueKey('doctor-date-picker'));
        await tester.ensureVisible(picker);
        await tester.tap(picker);
        await tester.pumpAndSettle();
        Navigator.of(tester.element(find.byType(DatePickerDialog))).pop(date);
        await tester.pumpAndSettle();
        final section = tester.widget<DoctorTodayAppointmentsSection>(
          find.byType(DoctorTodayAppointmentsSection),
        );
        expect(section.selectedDate, date);
        final visible = section.schedules
            .where((schedule) => DateUtils.isSameDay(schedule.workDate, date))
            .toList();
        expect(visible, hasLength([1, 0, 2][offset]));
        final totals = tester
            .widgetList<DoctorDashboardStatCard>(
              find.byType(DoctorDashboardStatCard),
            )
            .map((card) => card.value)
            .toList();
        final booked = [12, 0, 20][offset];
        expect(totals, [booked, 0, booked]);
        if (offset == 0) {
          expect(visible.single.startTime, '06:30');
          expect(find.textContaining('Buổi chiều (Thứ'), findsNothing);
          expect(find.text('06:30 - 07:30'), findsOneWidget);
        } else if (offset == 1) {
          expect(find.text('Chủ nhật không có ca khám'), findsOneWidget);
          expect(find.text('06:30 - 07:30'), findsNothing);
        } else {
          expect(find.text('13:00 - 14:00'), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'Saturday has morning only and Sunday has no schedules across month boundary',
    (tester) async {
      final schedules = DoctorHomeDemoData.schedules(DateTime(2026, 10, 30));
      final slots = DoctorHomeDemoData.timeSlots(schedules);
      final counts = DoctorHomeDemoData.counts(schedules);
      final saturday = schedules
          .where((schedule) => schedule.workDate == DateTime(2026, 10, 31))
          .toList();
      expect(saturday, hasLength(1));
      expect(saturday.single.startTime, '06:30');
      expect(counts[saturday.single.id]!.booked, 12);
      expect(
        schedules.where(
          (schedule) => schedule.workDate?.weekday == DateTime.sunday,
        ),
        isEmpty,
      );
      Future<void> showDate(DateTime date) => tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: DoctorTodayAppointmentsSection(
                selectedDate: date,
                state: DoctorAppointmentsDisplayState.data,
                schedules: schedules,
                timeSlots: slots,
                demoCounts: counts,
              ),
            ),
          ),
        ),
      );
      await showDate(DateTime(2026, 10, 31));
      expect(find.text('31/10/2026 - Buổi sáng (Thứ 7)'), findsOneWidget);
      expect(find.textContaining('Buổi chiều'), findsNothing);
      expect(find.text('06:30 - 07:30'), findsOneWidget);
      await showDate(DateTime(2026, 11, 1));
      expect(find.text('Chủ nhật không có ca khám'), findsOneWidget);
      expect(find.textContaining('Buổi sáng'), findsNothing);
      expect(find.textContaining('Buổi chiều'), findsNothing);
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
    'Verified schedules filter by date and show aggregate-only details',
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
            ),
          ),
        ),
      );
      await tester.tap(find.text('08:00 - 12:00'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('doctor-slot-other-day')), findsNothing);
      expect(find.text('Chi tiết lịch làm việc'), findsOneWidget);
      expect(find.text('Bệnh nhân đã khám: Chưa có dữ liệu'), findsOneWidget);
      expect(find.text('Danh sách bệnh nhân'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Slot cards use capacity and booking status and exclude other doctors',
    (tester) async {
      final date = DateTime(2026, 10, 23);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: DoctorTodayAppointmentsSection(
                selectedDate: date,
                state: DoctorAppointmentsDisplayState.data,
                schedules: [
                  WorkSchedule(
                    id: 'schedule',
                    doctorId: 'doctor',
                    workDate: date,
                  ),
                ],
                timeSlots: [
                  const TimeSlot(
                    id: 'full',
                    workScheduleId: 'schedule',
                    doctorId: 'doctor',
                    startTime: '06:30',
                    endTime: '07:30',
                    capacity: 3,
                    bookedCount: 4,
                    status: TimeSlotStatus.available,
                  ),
                  const TimeSlot(
                    id: 'booked',
                    workScheduleId: 'schedule',
                    doctorId: 'doctor',
                    startTime: '07:30',
                    endTime: '08:30',
                    status: TimeSlotStatus.booked,
                  ),
                  const TimeSlot(
                    id: 'open',
                    workScheduleId: 'schedule',
                    doctorId: 'doctor',
                    startTime: '13:00',
                    endTime: '14:00',
                    capacity: 4,
                    bookedCount: 2,
                    status: TimeSlotStatus.available,
                  ),
                  const TimeSlot(
                    id: 'foreign',
                    workScheduleId: 'schedule',
                    doctorId: 'other',
                    startTime: '15:00',
                    endTime: '16:00',
                    status: TimeSlotStatus.available,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      expect(find.text('23/10/2026 - Buổi sáng (Thứ 6)'), findsOneWidget);
      expect(find.text('23/10/2026 - Buổi chiều (Thứ 6)'), findsOneWidget);
      expect(find.text('Đã đặt hết'), findsNWidgets(2));
      expect(
        tester
            .widget<Material>(find.byKey(const ValueKey('doctor-slot-full')))
            .color,
        AppColors.divider,
      );
      expect(
        tester
            .widget<Material>(find.byKey(const ValueKey('doctor-slot-open')))
            .color,
        AppColors.primarySoft,
      );
      expect(find.byKey(const ValueKey('doctor-slot-foreign')), findsNothing);
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
