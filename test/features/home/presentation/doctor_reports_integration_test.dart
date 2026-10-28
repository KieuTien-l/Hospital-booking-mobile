import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_4/core/themes/app_theme.dart';
import 'package:flutter_application_4/features/home/domain/entities/doctor_workspace.dart';
import 'package:flutter_application_4/features/home/presentation/controllers/doctor_workspace_controller.dart';
import 'package:flutter_application_4/features/home/presentation/pages/doctor_reports_page.dart';

import '../doctor_test_support.dart';

Future<void> pumpReports(
  WidgetTester tester,
  TestWorkspaceRepository repository, {
  double scale = 1,
}) async {
  final workspace = DoctorWorkspaceController(
    repository: repository,
    userId: 'account',
    refreshInterval: null,
  );
  addTearDown(workspace.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: DoctorReportsPage(
          selectedDate: DateTime(2026, 10, 19),
          workspace: workspace,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> fillReport(WidgetTester tester) async {
  final type = find.byKey(const ValueKey('doctor-report-type'));
  await tester.ensureVisible(type);
  await tester.tap(type);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Bận đột xuất').last);
  await tester.pumpAndSettle();
  final schedule = find.byWidgetPredicate(
    (widget) =>
        widget is DropdownButtonFormField<String> &&
        widget.key.toString().contains('doctor-report-schedule'),
  );
  await tester.ensureVisible(schedule);
  await tester.tap(schedule);
  await tester.pumpAndSettle();
  await tester.tap(find.text('06:30 - 11:30').last);
  await tester.pumpAndSettle();
  final reason = find.byKey(const ValueKey('doctor-report-reason'));
  await tester.ensureVisible(reason);
  await tester.enterText(reason, 'Lý do kiểm thử');
  final description = find.byKey(const ValueKey('doctor-report-description'));
  await tester.ensureVisible(description);
  await tester.enterText(description, 'Mô tả kiểm thử được giữ khi gửi lỗi.');
}

void main() {
  testWidgets(
    'Report preserves its draft on failure and retries once with the same key',
    (tester) async {
      final repository = TestWorkspaceRepository();
      final keys = <String>[];
      final first = Completer<DoctorReport>();
      repository.sender = (draft) {
        keys.add(draft.requestId);
        expect(draft.scheduleId, 'DEMO-5-SANG');
        expect(draft.reason, 'Lý do kiểm thử');
        return first.future;
      };
      await pumpReports(tester, repository);
      await fillReport(tester);
      final send = find.widgetWithText(FilledButton, 'Gửi báo cáo cho Admin');
      await tester.ensureVisible(send);
      await tester.tap(send);
      await tester.pump();
      final sending = find.widgetWithText(FilledButton, 'Đang gửi báo cáo…');
      expect(tester.widget<FilledButton>(sending).onPressed, isNull);
      expect(repository.sendCalls, 1);
      first.completeError(StateError('offline'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Gửi báo cáo thất bại. Nội dung được giữ lại để bạn thử lại.',
        ),
        findsOneWidget,
      );
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('doctor-report-reason')),
            )
            .controller!
            .text,
        'Lý do kiểm thử',
      );
      repository.sender = (draft) async {
        keys.add(draft.requestId);
        return DoctorReport(
          id: 'saved',
          type: draft.type,
          date: draft.date,
          reason: draft.reason,
          status: DoctorReportStatus.pending,
          adminResponse: 'Admin đã tiếp nhận',
        );
      };
      await tester.tap(send);
      await tester.pumpAndSettle();
      expect(keys, hasLength(2));
      expect(keys[0], keys[1]);
      expect(repository.sendCalls, 2);
      expect(
        find.text('Đã gửi báo cáo. Đang chờ Admin xử lý.'),
        findsOneWidget,
      );
      expect(find.text('Admin đã tiếp nhận'), findsOneWidget);
      expect(tester.widget<FilledButton>(send).onPressed, isNull);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'History and assigned schedules show failures and recover through retry',
    (tester) async {
      final repository = TestWorkspaceRepository();
      repository.historyLoader = () => Future.error(StateError('offline'));
      repository.dayLoader = (_) => Future.error(StateError('offline'));
      await pumpReports(tester, repository);
      expect(find.text('Không thể tải ca được phân công.'), findsOneWidget);
      expect(find.text('Không thể tải lịch sử báo cáo.'), findsOneWidget);
      repository.dayLoader = (date) async => testDay(date);
      repository.historyLoader = () async => [
        DoctorReport(
          id: 'approved',
          type: 'Khác',
          date: DateTime(2026, 10, 19),
          reason: 'Báo cáo mẫu kiểm thử',
          status: DoctorReportStatus.approved,
          adminResponse: 'Đã xác nhận',
        ),
      ];
      final retrySchedule = find.text('Thử lại tải ca');
      await tester.ensureVisible(retrySchedule);
      await tester.tap(retrySchedule);
      await tester.pumpAndSettle();
      final retryHistory = find.text('Thử lại lịch sử');
      await tester.ensureVisible(retryHistory);
      await tester.tap(retryHistory);
      await tester.pumpAndSettle();
      expect(find.text('Không thể tải ca được phân công.'), findsNothing);
      expect(find.text('Không thể tải lịch sử báo cáo.'), findsNothing);
      expect(find.text('Đã phê duyệt\nĐã xác nhận'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Connected report form fits small screens with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpReports(tester, TestWorkspaceRepository(), scale: 2);
    final send = find.widgetWithText(FilledButton, 'Gửi báo cáo cho Admin');
    await tester.ensureVisible(send);
    await tester.tap(send);
    await tester.pumpAndSettle();
    expect(find.text('Vui lòng chọn ca được phân công.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
