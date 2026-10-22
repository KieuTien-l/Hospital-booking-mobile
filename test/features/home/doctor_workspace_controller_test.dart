import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_4/features/doctors/domain/entities/work_schedule.dart';
import 'package:flutter_application_4/features/home/domain/entities/doctor_workspace.dart';
import 'package:flutter_application_4/features/home/domain/repositories/doctor_workspace_repository.dart';
import 'package:flutter_application_4/features/home/presentation/controllers/doctor_workspace_controller.dart';
import 'package:flutter_application_4/features/home/presentation/controllers/doctor_reports_controller.dart';

import 'doctor_test_support.dart';

void main() {
  final monday = DateTime(2026, 10, 19), tuesday = DateTime(2026, 10, 20);
  test('A late request cannot overwrite a newer selected day', () async {
    final old = Completer<DoctorDayData>(), latest = Completer<DoctorDayData>();
    final repository = TestWorkspaceRepository()
      ..dayLoader = (date) => date == monday ? old.future : latest.future;
    final controller = DoctorWorkspaceController(
      repository: repository,
      userId: 'account',
      refreshInterval: null,
    );
    addTearDown(controller.dispose);
    final a = controller.load(monday), b = controller.load(tuesday);
    latest.complete(testDay(tuesday));
    await b;
    old.complete(testDay(monday));
    await a;
    expect(controller.data!.date, tuesday);
    expect(controller.isSuccess, isTrue);
  });
  test(
    'Transient refresh errors retain same-day data; switching day clears it',
    () async {
      final repository = TestWorkspaceRepository();
      final controller = DoctorWorkspaceController(
        repository: repository,
        userId: 'account',
        refreshInterval: null,
      );
      addTearDown(controller.dispose);
      await controller.load(monday);
      repository.dayLoader = (_) => Future.error(StateError('offline'));
      await controller.refresh();
      expect(controller.hasError, isTrue);
      expect(controller.data!.date, monday);
      await controller.load(tuesday);
      expect(controller.data, isNull);
    },
  );
  test(
    'Access errors clear patient data instead of keeping a stale copy',
    () async {
      final repository = TestWorkspaceRepository();
      final controller = DoctorWorkspaceController(
        repository: repository,
        userId: 'account',
        refreshInterval: null,
      );
      addTearDown(controller.dispose);
      await controller.load(monday);
      repository.dayLoader = (_) => Future.error(
        const DoctorWorkspaceAccessException('permission denied'),
      );
      await controller.refresh();
      expect(controller.data, isNull);
      expect(controller.hasError, isTrue);
    },
  );
  test(
    'Foreign doctor responses and forbidden weekend schedules are rejected',
    () async {
      final repository = TestWorkspaceRepository()
        ..dayLoader = (date) async => testDay(date, userId: 'other');
      final controller = DoctorWorkspaceController(
        repository: repository,
        userId: 'account',
        refreshInterval: null,
      );
      addTearDown(controller.dispose);
      await controller.load(monday);
      expect(controller.data, isNull);
      expect(controller.hasError, isTrue);
      for (final date in [DateTime(2026, 10, 17), DateTime(2026, 10, 18)]) {
        final data = testDay(date);
        final invalid = DoctorDayData(
          doctor: data.doctor,
          date: date,
          schedules: [
            WorkSchedule(
              id: 'invalid',
              doctorId: data.doctor.id,
              workDate: date,
              startTime: '13:00',
              endTime: '16:00',
            ),
          ],
          slots: [],
          bookings: [],
        );
        expect(
          () => DoctorWorkspaceController.validate(
            invalid,
            userId: 'account',
            date: date,
          ),
          throwsStateError,
        );
      }
    },
  );
  test('A completed request cannot restore data after disposal', () async {
    final completer = Completer<DoctorDayData>();
    final repository = TestWorkspaceRepository()
      ..dayLoader = (_) => completer.future;
    final controller = DoctorWorkspaceController(
      repository: repository,
      userId: 'account',
      refreshInterval: null,
    );
    final request = controller.load(monday);
    controller.dispose();
    completer.complete(testDay(monday));
    await request;
    expect(controller.data, isNull);
  });
  testWidgets('Configured polling refreshes and is cancelled on disposal', (
    tester,
  ) async {
    final repository = TestWorkspaceRepository();
    final controller = DoctorWorkspaceController(
      repository: repository,
      userId: 'account',
      refreshInterval: const Duration(seconds: 1),
    );
    final future = controller.load(monday);
    await tester.pump();
    await future;
    expect(repository.dayCalls, 1);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(repository.dayCalls, 2);
    controller.pause();
    await tester.pump(const Duration(seconds: 2));
    expect(repository.dayCalls, 2);
    controller.resume();
    await tester.pump();
    expect(repository.dayCalls, 3);
    controller.dispose();
    await tester.pump(const Duration(seconds: 2));
    expect(repository.dayCalls, 3);
  });
  test('Report send blocks duplicate taps and permits retry with the same request ID', () async {
    final repository = TestWorkspaceRepository();
    final controller = DoctorReportsController(
      repository: repository,
      userId: 'account',
    );
    addTearDown(controller.dispose);
    await controller.loadSchedules(monday);
    final draft = DoctorReportDraft(
      type: 'Bận đột xuất',
      scheduleId: controller.schedules.first.id,
      date: monday,
      reason: 'Có việc đột xuất',
      description: 'Nội dung kiểm thử',
      requestId: 'same-request',
    );
    final pending = Completer<DoctorReport>();
    repository.sender = (_) => pending.future;
    final first = controller.send(draft);
    expect(await controller.send(draft), isFalse);
    expect(repository.sendCalls, 1);
    pending.completeError(StateError('offline'));
    expect(await first, isFalse);
    expect(controller.sendError, isNotNull);
    repository.sender = (retry) async {
      expect(retry.requestId, 'same-request');
      return DoctorReport(
        id: 'saved',
        type: retry.type,
        date: retry.date,
        reason: retry.reason,
        status: DoctorReportStatus.pending,
      );
    };
    expect(await controller.send(draft), isTrue);
    expect(controller.reports.single.id, 'saved');
    expect(repository.sendCalls, 2);
  });
  test(
    'A delayed history response cannot erase a successfully sent report',
    () async {
      final repository = TestWorkspaceRepository();
      final controller = DoctorReportsController(
        repository: repository,
        userId: 'account',
      );
      addTearDown(controller.dispose);
      await controller.loadSchedules(monday);
      final history = Completer<List<DoctorReport>>();
      repository.historyLoader = () => history.future;
      final load = controller.loadHistory();
      final success = await controller.send(
        DoctorReportDraft(
          type: 'Khác',
          scheduleId: controller.schedules.first.id,
          date: monday,
          reason: 'Lý do',
          description: 'Nội dung',
          requestId: 'new-report',
        ),
      );
      expect(success, isTrue);
      history.complete([]);
      await load;
      expect(controller.reports.single.id, 'new-report');
      expect(controller.loading, isFalse);
    },
  );
}
