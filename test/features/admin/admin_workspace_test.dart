import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_4/core/themes/app_theme.dart';
import 'package:flutter_application_4/features/admin/data/admin_repository.dart';
import 'package:flutter_application_4/features/admin/data/admin_commands.dart';
import 'package:flutter_application_4/features/admin/data/admin_doctor_provisioner.dart';
import 'package:flutter_application_4/features/admin/presentation/admin_controller.dart';
import 'package:flutter_application_4/features/admin/presentation/admin_workspace.dart';

class _Commands implements AdminCommands {
  final calls = <Map<String, dynamic>>[];
  final emails = <String>[];
  @override
  Future<Map<String, dynamic>> execute(Map<String, dynamic> command) async {
    calls.add(command);
    return {
      'id': 'new-doctor',
      'message': 'Đã lưu',
      if (command['operation'] == 'createDoctor' ||
          command['operation'] == 'passwordSetup')
        'loginEmail': 'doctor@example.com',
    };
  }

  @override
  Future<void> sendPasswordSetup(String email) async {
    emails.add(email);
  }
}

class _DoctorProvisioner implements DoctorAccountProvisioner {
  final calls = <Map<String, dynamic>>[];
  final emails = <String>[];

  @override
  Future<DoctorAccountProvisioningResult> provision(
    Map<String, dynamic> values, {
    required String requestId,
    required String reason,
  }) async {
    calls.add(values);
    return const DoctorAccountProvisioningResult(
      doctorId: 'new-doctor',
      loginEmail: 'doctor@example.com',
      passwordSetupSent: true,
    );
  }

  @override
  Future<void> sendPasswordSetup(String email) async {
    emails.add(email);
  }
}

class _Repository implements AdminRepository {
  final streams = <String, StreamController<List<AdminRecord>>>{};

  @override
  Stream<List<AdminRecord>> watch(String collection) => streams
      .putIfAbsent(
        collection,
        () => StreamController<List<AdminRecord>>.broadcast(),
      )
      .stream;

  void emit(String collection, List<AdminRecord> records) =>
      streams[collection]!.add(records);

  Future<void> close() async {
    for (final stream in streams.values) {
      await stream.close();
    }
  }
}

void main() {
  Future<void> capture(WidgetTester tester, String name) async {
    if (!const bool.fromEnvironment('ADMIN_CAPTURE')) return;
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('capture')),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('build/admin-preview/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  test('empty data uses demo; permission errors never become demo; later data recovers', () async {
    final repository = _Repository();
    final controller = AdminController(repository)..start();
    repository.emit('LICH_HEN', []);
    await Future<void>.delayed(Duration.zero);
    expect(controller.dataset('LICH_HEN').useDemo, isTrue);
    repository.streams['LICH_HEN']!.addError(
      FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
    );
    await Future<void>.delayed(Duration.zero);
    expect(controller.dataset('LICH_HEN').useDemo, isFalse);
    expect(controller.dataset('LICH_HEN').error, contains('quyền đọc'));
    repository.emit('LICH_HEN', [
      const AdminRecord('real-id', {'status': 'PENDING'}),
    ]);
    await Future<void>.delayed(Duration.zero);
    expect(controller.dataset('LICH_HEN').records.single.id, 'real-id');
    expect(controller.dataset('LICH_HEN').error, isNull);
    controller.dispose();
    await repository.close();
  });

  test('reference joins and Firebase sample labels stay distinct', () async {
    final repository = _Repository();
    final controller = AdminController(repository)..start();
    repository.emit('BAC_SI', [
      const AdminRecord('doctor-1', {'fullName': 'Bác sĩ A'}),
    ]);
    await Future<void>.delayed(Duration.zero);
    expect(controller.referenceName('doctorId', 'doctor-1'), 'Bác sĩ A');
    expect(controller.referenceName('doctorId', 'missing'), 'missing');
    expect(const AdminRecord('a', {'seedVersion': 1}).isSample, isTrue);
    expect(const AdminRecord('b', {'isTestData': true}).isSample, isTrue);
    expect(const AdminRecord('c', {'fullName': 'A'}).isSample, isFalse);
    controller.dispose();
    await repository.close();
  });

  Future<void> pumpWorkspace(
    WidgetTester tester,
    _Repository repository,
    Size size, {
    AdminCommands? commands,
    DoctorAccountProvisioner? doctorProvisioner,
  }) async {
    await tester.runAsync(() async {
      final font = FontLoader('BeVietnamPro')
        ..addFont(
          rootBundle.load(
            'assets/fonts/be_vietnam_pro/BeVietnamPro-Regular.ttf',
          ),
        );
      final icons = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await Future.wait([font.load(), icons.load()]);
    });
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('capture'),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          home: AdminWorkspace(
            userName: 'Admin',
            onLogout: () {},
            repository: repository,
            commands: commands,
            doctorProvisioner: doctorProvisioner,
          ),
        ),
      ),
    );
    for (final stream in repository.streams.values) {
      stream.add([]);
    }
    await tester.pumpAndSettle();
    await capture(tester, 'overview-${size.width.toInt()}');
    if (const bool.fromEnvironment('ADMIN_CAPTURE')) {
      await tester.ensureVisible(find.text('Truy cập nhanh'));
      await tester.pumpAndSettle();
      await capture(tester, 'quick-access-${size.width.toInt()}');
      tester
          .widget<SingleChildScrollView>(
            find.byType(SingleChildScrollView).first,
          )
          .controller!
          .jumpTo(0);
      await tester.pumpAndSettle();
    }
  }

  testWidgets(
    'desktop searches real records, filters status and opens details',
    (tester) async {
      final repository = _Repository();
      await pumpWorkspace(tester, repository, const Size(1440, 1000));
      repository.emit('LICH_HEN', [
        const AdminRecord('APPT-A', {'patientId': 'An', 'status': 'PENDING'}),
        const AdminRecord('APPT-B', {
          'patientId': 'Bình',
          'status': 'CONFIRMED',
        }),
      ]);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Lịch hẹn'));
      await tester.pumpAndSettle();
      expect(find.text('APPT-A'), findsOneWidget);
      expect(find.text('APPT-B'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Bình');
      await tester.pumpAndSettle();
      expect(find.text('APPT-A'), findsNothing);
      await tester.tap(find.text('APPT-B'));
      await tester.pumpAndSettle();
      expect(find.text('Chi tiết lịch hẹn'), findsOneWidget);
      await tester.tap(find.text('Đóng'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '');
      await tester.tap(
        find.byWidgetPredicate(
          (w) =>
              w is DropdownButtonFormField<String> &&
              w.decoration.labelText == 'Trạng thái',
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Đã xác nhận').last);
      await tester.pumpAndSettle();
      expect(find.text('APPT-A'), findsNothing);
      expect(find.text('APPT-B'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await repository.close();
    },
  );

  testWidgets(
    'mobile drawer, demo notice and horizontal table fit without overflow',
    (tester) async {
      final repository = _Repository();
      await pumpWorkspace(tester, repository, const Size(390, 844));
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Open navigation menu'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Lịch hẹn'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Collection LICH_HEN chưa có bản ghi'),
        findsOneWidget,
      );
      expect(find.text('DEMO cục bộ'), findsOneWidget);
      expect(tester.takeException(), isNull);
      repository.streams['LICH_HEN']!.addError(
        FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
      );
      await tester.pumpAndSettle();
      expect(find.text('DEMO cục bộ'), findsNothing);
      expect(find.textContaining('quyền đọc'), findsOneWidget);
      await tester.tap(find.text('Xem giao diện DEMO'));
      await tester.pumpAndSettle();
      expect(find.text('DEMO cục bộ'), findsOneWidget);
      expect(find.textContaining('Chưa xác minh được dữ liệu'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await repository.close();
    },
  );

  testWidgets('every admin section remains accessible on desktop and mobile', (
    tester,
  ) async {
    final repository = _Repository();
    await pumpWorkspace(tester, repository, const Size(1440, 1000));
    const titles = [
      'Tổng quan',
      'Báo cáo',
      'Lịch hẹn',
      'Lịch làm việc',
      'Ca khám',
      'Bác sĩ',
      'Chuyên khoa',
      'Bệnh nhân',
      'Thanh toán',
      'Yêu cầu hoàn tiền',
      'Phản hồi',
      'Thông báo',
      'Tài khoản',
      'Cấp tài khoản',
      'Hồ sơ sức khỏe',
      'Kết quả CLS',
      'Tư vấn AI',
      'Cấu hình',
      'Nhật ký hoạt động',
    ];
    for (final title in titles) {
      final item = find.widgetWithText(ListTile, title);
      await tester.scrollUntilVisible(
        item,
        160,
        scrollable: find.byType(Scrollable).first,
      );
      await Scrollable.ensureVisible(tester.element(item), alignment: .5);
      await tester.pumpAndSettle();
      await tester.tap(item.hitTestable());
      await tester.pumpAndSettle();
      expect(tester.widget<ListTile>(item).selected, isTrue);
      expect(tester.takeException(), isNull, reason: 'Desktop: $title');
      await capture(tester, 'section-${titles.indexOf(title)}-1440');
    }
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();
    for (final title in titles) {
      await tester.tap(find.byTooltip('Open navigation menu'));
      await tester.pumpAndSettle();
      final item = find.widgetWithText(ListTile, title);
      final menuScroll = find
          .descendant(
            of: find.byType(Drawer),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(item, 160, scrollable: menuScroll);
      await Scrollable.ensureVisible(tester.element(item), alignment: .5);
      await tester.pumpAndSettle();
      await tester.tap(item.hitTestable());
      await tester.pumpAndSettle();
      expect(find.byType(Drawer), findsNothing);
      expect(tester.takeException(), isNull, reason: 'Mobile: $title');
      await capture(tester, 'section-${titles.indexOf(title)}-390');
    }
    await tester.pumpWidget(const SizedBox());
    await repository.close();
  });

  testWidgets('ADM-18 admin opens and reviews a doctor request', (
    tester,
  ) async {
    final repository = _Repository(), commands = _Commands();
    await pumpWorkspace(
      tester,
      repository,
      const Size(1440, 1000),
      commands: commands,
    );
    repository.emit('YEU_CAU_BAC_SI', [
      AdminRecord('REQUEST-1', {
        'senderId': 'doctor-user',
        'doctorId': 'doctor-1',
        'scheduleId': 'schedule-1',
        'type': 'Bận đột xuất',
        'reason': 'Xin đổi ca',
        'status': 'PENDING',
        'date': DateTime(2026, 11, 2),
        'createdAt': DateTime(2026, 10, 22),
      }),
    ]);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Yêu cầu bác sĩ'));
    await tester.pumpAndSettle();
    expect(find.text('REQUEST-1'), findsOneWidget);
    await capture(tester, 'doctor-requests-1440');
    await tester.tap(find.text('REQUEST-1'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Thao tác quản trị').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Duyệt / trả lời yêu cầu'));
    await tester.pumpAndSettle();
    final status = find.byWidgetPredicate(
      (w) =>
          w is DropdownButtonFormField<String> &&
          w.decoration.labelText == 'Kết quả xử lý',
    );
    await tester.tap(status);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Phê duyệt').last);
    await tester.pumpAndSettle();
    Finder input(String label) => find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.labelText == label,
    );
    await tester.enterText(
      input('Phản hồi bác sĩ'),
      'Đã tiếp nhận yêu cầu đổi ca.',
    );
    await tester.enterText(
      input('Lý do thao tác / ghi chú quản trị'),
      'Duyệt yêu cầu hợp lệ',
    );
    await capture(tester, 'doctor-request-review-1440');
    await tester.tap(find.text('Xác nhận'));
    await tester.pumpAndSettle();
    expect(commands.calls.single['operation'], 'reviewDoctorRequest');
    expect(commands.calls.single['id'], 'REQUEST-1');
    expect(commands.calls.single['values']['status'], 'APPROVED');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await repository.close();
  });

  testWidgets(
    'statistics dropdown applies calendar month, year and custom periods',
    (tester) async {
      final repository = _Repository();
      await pumpWorkspace(tester, repository, const Size(390, 844));
      final now = DateTime.now().toUtc().add(const Duration(hours: 7));
      String dateText(DateTime date) =>
          '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
      Future<void> choose(String text) async {
        final dropdown = find.byType(DropdownButton<String>);
        await tester.ensureVisible(dropdown);
        await tester.tap(dropdown);
        await tester.pumpAndSettle();
        await tester.tap(find.text(text).last);
        await tester.pumpAndSettle();
      }

      Future<void> checkPeriod(String label) async {
        expect(find.text(label), findsNothing);
        final metric = find.text('Lịch khám trong kỳ').first;
        await tester.ensureVisible(metric);
        await tester.tap(metric);
        await tester.pumpAndSettle();
        expect(find.text(label), findsOneWidget);
        await tester.tap(find.byTooltip('Open navigation menu'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ListTile, 'Tổng quan'));
        await tester.pumpAndSettle();
      }

      await choose('Tháng này');
      final monthLabel =
          '${dateText(DateTime(now.year, now.month))} – ${dateText(DateTime(now.year, now.month + 1, 0))}';
      await checkPeriod(monthLabel);
      await choose('Năm nay');
      final yearLabel = '01/01/${now.year} – 31/12/${now.year}';
      await checkPeriod(yearLabel);
      await choose('Tùy chọn');
      expect(find.byType(DateRangePickerDialog), findsOneWidget);
      tester.state<NavigatorState>(find.byType(Navigator).last).pop();
      await tester.pumpAndSettle();
      await checkPeriod(yearLabel);
      expect(
        tester
            .widget<DropdownButton<String>>(find.byType(DropdownButton<String>))
            .value,
        'year',
      );
      await choose('Tùy chọn');
      tester
          .state<NavigatorState>(find.byType(Navigator).last)
          .pop(
            DateTimeRange(
              start: DateTime(now.year, 2, 1),
              end: DateTime(now.year, 2, 5),
            ),
          );
      await tester.pumpAndSettle();
      await checkPeriod('01/02/${now.year} – 05/02/${now.year}');
      expect(
        tester
            .widget<DropdownButton<String>>(find.byType(DropdownButton<String>))
            .value,
        'custom',
      );
      await capture(tester, 'statistics-custom-390');
      await choose('Hôm nay');
      await checkPeriod('${dateText(now)} – ${dateText(now)}');
      tester.view.physicalSize = const Size(320, 780);
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await repository.close();
    },
  );

  testWidgets(
    'admin can create a specialty but local DEMO records never expose write actions',
    (tester) async {
      final repository = _Repository(), commands = _Commands();
      await pumpWorkspace(
        tester,
        repository,
        const Size(1440, 1000),
        commands: commands,
      );
      final menu = find.widgetWithText(ListTile, 'Chuyên khoa');
      await tester.scrollUntilVisible(
        menu,
        160,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(menu);
      await tester.pumpAndSettle();
      await tester.tap(find.text('DEMO-001'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Thao tác quản trị'), findsNothing);
      await tester.tap(find.text('Đóng'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Thêm chuyên khoa'));
      await tester.pumpAndSettle();
      Finder input(String label) => find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == label,
      );
      await tester.enterText(input('Tên chuyên khoa'), 'Nội tổng quát');
      await tester.enterText(input('Mô tả'), 'Chuyên khoa khám nội');
      await tester.enterText(
        input('Lý do thao tác / ghi chú quản trị'),
        'Bổ sung danh mục',
      );
      await tester.tap(find.text('Tạo'));
      await tester.pumpAndSettle();
      expect(commands.calls.single['operation'], 'create');
      expect(commands.calls.single['collection'], 'CHUYEN_KHOA');
      expect((commands.calls.single['values'] as Map)['name'], 'Nội tổng quát');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await repository.close();
    },
  );

  testWidgets(
    'doctor creation delegates fixed-role provisioning and preserves the admin session',
    (tester) async {
      final repository = _Repository(), commands = _Commands();
      final doctorProvisioner = _DoctorProvisioner();
      await pumpWorkspace(
        tester,
        repository,
        const Size(1440, 1000),
        commands: commands,
        doctorProvisioner: doctorProvisioner,
      );
      repository.emit('CHUYEN_KHOA', [
        const AdminRecord('SP-1', {'name': 'Nội', 'status': 'ACTIVE'}),
      ]);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Bác sĩ'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Thêm bác sĩ & tài khoản'));
      await tester.pumpAndSettle();
      Finder input(String label) => find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == label,
      );
      await tester.enterText(input('Họ và tên'), 'Bác sĩ mới');
      await tester.enterText(
        input('Email đăng nhập (admin cấp)'),
        'doctor@example.com',
      );
      final specialty = find
          .byWidgetPredicate(
            (w) =>
                w is DropdownButtonFormField<String> &&
                w.decoration.labelText == 'Chuyên khoa',
          )
          .last;
      await tester.ensureVisible(specialty);
      await tester.tap(specialty);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nội').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(input('Lý do thao tác / ghi chú quản trị'));
      await tester.enterText(
        input('Lý do thao tác / ghi chú quản trị'),
        'Cấp tài khoản bác sĩ mới',
      );
      await tester.ensureVisible(find.text('Tạo'));
      await tester.tap(find.text('Tạo'));
      await tester.pumpAndSettle();
      expect(commands.calls, isEmpty);
      expect(doctorProvisioner.calls, hasLength(1));
      expect(
        doctorProvisioner.calls.single['loginEmail'],
        'doctor@example.com',
      );
      expect(doctorProvisioner.calls.single['specialtyId'], 'SP-1');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await repository.close();
    },
  );

  void seedWorkspace(_Repository repository) {
    final now = DateTime.now().toUtc().add(const Duration(hours: 7));
    final date = DateTime.utc(now.year, now.month, now.day, 2);
    repository.emit('CHUYEN_KHOA', [
      const AdminRecord('SP-1', {'name': 'Nội tổng quát', 'status': 'ACTIVE'}),
    ]);
    repository.emit('BAC_SI', [
      const AdminRecord('DR-1', {
        'fullName': 'BS. Nguyễn Minh Anh',
        'specialtyId': 'SP-1',
        'phone': '0901234567',
        'consultationFee': 150000,
        'status': 'ACTIVE',
      }),
      const AdminRecord('DR-2', {
        'fullName': 'BS. Trần Hà',
        'specialtyId': 'SP-1',
        'status': 'ACTIVE',
      }),
    ]);
    repository.emit('BENH_NHAN', [
      const AdminRecord('PT-1', {
        'fullName': 'Nguyễn Hoàng An',
        'phone': '0912345678',
      }),
    ]);
    repository.emit('LICH_HEN', [
      AdminRecord('TODAY-PENDING', {
        'patientId': 'PT-1',
        'doctorId': 'DR-1',
        'specialtyId': 'SP-1',
        'appointmentDate': date,
        'startTime': '08:00',
        'status': 'PENDING',
        'workScheduleId': 'WS-1',
      }),
      AdminRecord('TODAY-CONFIRMED', {
        'patientId': 'PT-1',
        'doctorId': 'DR-2',
        'specialtyId': 'SP-1',
        'appointmentDate': date,
        'startTime': '09:00',
        'status': 'CONFIRMED',
      }),
      AdminRecord('OLD-PENDING', {
        'patientId': 'PT-1',
        'doctorId': 'DR-1',
        'appointmentDate': date.subtract(const Duration(days: 10)),
        'status': 'PENDING',
      }),
    ]);
    repository.emit('LICH_LAM_VIEC', [
      AdminRecord('WS-1', {
        'doctorId': 'DR-1',
        'workDate': date,
        'startTime': '08:00',
        'endTime': '11:00',
        'status': 'ACTIVE',
      }),
    ]);
    repository.emit('CA_KHAM', [
      const AdminRecord('SLOT-1', {
        'doctorId': 'DR-1',
        'workScheduleId': 'WS-1',
        'startTime': '08:00',
        'endTime': '08:30',
        'capacity': 5,
        'bookedCount': 2,
        'status': 'AVAILABLE',
      }),
    ]);
    repository.emit('THANH_TOAN', [
      AdminRecord('PAY-1', {
        'appointmentId': 'TODAY-PENDING',
        'patientId': 'PT-1',
        'status': 'PAID',
        'amount': 150000,
        'paidAt': date,
      }),
    ]);
  }

  testWidgets(
    'dashboard drilldown preserves period and absent status gives no results',
    (tester) async {
      final repository = _Repository();
      await pumpWorkspace(tester, repository, const Size(1440, 1000));
      seedWorkspace(repository);
      await tester.pumpAndSettle();
      expect(find.text('150.000 đ'), findsOneWidget);
      await capture(tester, 'overview-populated-1440');
      final metric = find.text('Lịch khám trong kỳ').first;
      await tester.ensureVisible(metric);
      await tester.tap(metric);
      await tester.pumpAndSettle();
      expect(find.text('TODAY-PENDING'), findsOneWidget);
      expect(find.text('TODAY-CONFIRMED'), findsOneWidget);
      expect(find.text('OLD-PENDING'), findsNothing);
      await capture(tester, 'appointments-1440');
      await tester.tap(find.widgetWithText(ChoiceChip, 'Hoàn thành'));
      await tester.pumpAndSettle();
      expect(find.text('Không có kết quả phù hợp.'), findsOneWidget);
      expect(find.text('TODAY-CONFIRMED'), findsNothing);
      await tester.tap(find.widgetWithText(ListTile, 'Tổng quan'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Tiền đã thu'));
      await tester.tap(find.text('Tiền đã thu'));
      await tester.pumpAndSettle();
      expect(find.text('PAY-1'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await repository.close();
    },
  );

  testWidgets(
    'combined filters survive navigation and related data remains readable',
    (tester) async {
      final repository = _Repository();
      await pumpWorkspace(tester, repository, const Size(1440, 1000));
      seedWorkspace(repository);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Lịch hẹn'));
      await tester.pumpAndSettle();
      final doctorFilter = find.byWidgetPredicate(
        (w) =>
            w is DropdownButtonFormField<String> &&
            w.decoration.labelText == 'Bác sĩ',
      );
      await tester.tap(doctorFilter);
      await tester.pumpAndSettle();
      await tester.tap(find.text('BS. Nguyễn Minh Anh').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'TODAY');
      await tester.pumpAndSettle();
      expect(find.text('TODAY-PENDING'), findsOneWidget);
      expect(find.text('TODAY-CONFIRMED'), findsNothing);
      await tester.tap(find.widgetWithText(ListTile, 'Bác sĩ'));
      await tester.pumpAndSettle();
      await capture(tester, 'doctors-1440');
      await tester.tap(find.widgetWithText(ListTile, 'Lịch hẹn'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'TODAY',
      );
      expect(find.text('TODAY-PENDING'), findsOneWidget);
      expect(find.text('TODAY-CONFIRMED'), findsNothing);
      await tester.tap(find.text('TODAY-PENDING'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(Tab, 'Liên quan'));
      await tester.pumpAndSettle();
      expect(find.text('PAY-1'), findsOneWidget);
      await capture(tester, 'appointment-detail-1440');
      await tester.tap(find.text('Đóng'));
      await tester.pumpAndSettle();
      expect(find.text('TODAY-PENDING'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await repository.close();
    },
  );

  testWidgets(
    'doctor creation and action menu fit a narrow phone with large text',
    (tester) async {
      final repository = _Repository();
      final commands = _Commands();
      await pumpWorkspace(
        tester,
        repository,
        const Size(1440, 1000),
        commands: commands,
      );
      seedWorkspace(repository);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Bác sĩ'));
      await tester.pumpAndSettle();
      tester.view.physicalSize = const Size(320, 780);
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Thêm bác sĩ & tài khoản'));
      await tester.tap(find.text('Thêm bác sĩ & tài khoản'));
      await tester.pumpAndSettle();
      expect(find.text('Thêm bác sĩ và cấp tài khoản'), findsOneWidget);
      await capture(tester, 'doctor-create-320');
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('DR-1'));
      await tester.tap(find.text('DR-1'));
      await tester.pumpAndSettle();
      expect(find.text('Thao tác quản trị'), findsOneWidget);
      await tester.tap(find.text('Thao tác quản trị'));
      await tester.pumpAndSettle();
      expect(find.text('Chỉnh sửa thông tin'), findsOneWidget);
      await capture(tester, 'doctor-actions-320');
      expect(tester.takeException(), isNull);
      expect(commands.calls, isEmpty);
      await tester.pumpWidget(const SizedBox());
      await repository.close();
    },
  );

  testWidgets(
    'schedule day view opens related slots and narrow cards fit large text',
    (tester) async {
      final repository = _Repository();
      await pumpWorkspace(tester, repository, const Size(1440, 1000));
      seedWorkspace(repository);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Lịch làm việc'));
      await tester.pumpAndSettle();
      final statusFilter = find.byWidgetPredicate(
        (w) =>
            w is DropdownButtonFormField<String> &&
            w.decoration.labelText == 'Trạng thái',
      );
      await tester.tap(statusFilter);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Không hoạt động').last);
      await tester.pumpAndSettle();
      expect(find.text('Không có kết quả phù hợp.'), findsOneWidget);
      expect(find.text('WS-1'), findsNothing);
      await tester.tap(statusFilter);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tất cả').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Theo ngày'));
      await tester.pumpAndSettle();
      await capture(tester, 'schedules-1440');
      await tester.tap(find.text('WS-1'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(Tab, 'Liên quan'));
      await tester.pumpAndSettle();
      expect(find.text('SLOT-1'), findsOneWidget);
      await tester.tap(find.text('Đóng'));
      await tester.pumpAndSettle();
      tester.view.physicalSize = const Size(320, 780);
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Open navigation menu'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Lịch hẹn'));
      await tester.pumpAndSettle();
      await capture(tester, 'appointments-320');
      expect(find.byType(DataTable), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await repository.close();
    },
  );
}
