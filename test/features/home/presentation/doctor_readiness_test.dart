import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application_4/core/routes/auth_gate.dart';
import 'package:flutter_application_4/core/themes/app_theme.dart';
import 'package:flutter_application_4/features/auth/presentation/controllers/auth_controller.dart';
import 'package:flutter_application_4/features/auth/presentation/pages/login_page.dart';
import 'package:flutter_application_4/features/appointments/domain/entities/appointment.dart';
import 'package:flutter_application_4/features/doctors/domain/entities/time_slot.dart';
import 'package:flutter_application_4/features/home/domain/entities/doctor_workspace.dart';
import 'package:flutter_application_4/features/home/domain/repositories/doctor_workspace_repository.dart';
import 'package:flutter_application_4/features/home/presentation/controllers/doctor_workspace_controller.dart';
import 'package:flutter_application_4/features/home/presentation/pages/doctor_profile_page.dart';
import 'package:flutter_application_4/features/home/presentation/pages/doctor_home_page.dart';
import 'package:flutter_application_4/features/home/presentation/pages/doctor_slot_details_page.dart';
import 'package:flutter_application_4/features/home/presentation/widgets/doctor_dashboard_stat_card.dart';
import 'package:flutter_application_4/features/home/presentation/widgets/doctor_today_appointments_section.dart';

import '../doctor_test_support.dart';

import 'package:flutter_application_4/features/home/data/repositories/http_doctor_workspace_repository.dart';

Future<TestAuthRepository> pumpAuth(
  WidgetTester tester, {
  Widget? home,
  DoctorWorkspaceRepository? repository,
}) async {
  final repo = TestAuthRepository();
  final auth = AuthController(authRepo: repo);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    auth.dispose();
    await repo.events.close();
  });
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: auth),
        if (repository != null)
          Provider<DoctorWorkspaceRepository>.value(value: repository),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: home ?? const AuthGate(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}

void main() {
  final day = testDay(DateTime(2026, 10, 16));
  final schedule = day.schedules.first;
  final slot = day.slots.first;
  testWidgets(
    'System back pops a doctor detail route and preserves the doctor home',
    (tester) async {
      await pumpAuth(tester);
      Navigator.of(tester.element(find.byType(DoctorHomePage))).push(
        MaterialPageRoute<void>(
          builder: (_) => DoctorSlotDetailsPage(
            schedule: schedule,
            slot: slot,
            bookings: day.bookings,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(DoctorSlotDetailsPage), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(DoctorSlotDetailsPage), findsNothing);
      expect(find.byType(DoctorHomePage), findsOneWidget);
      expect(find.byType(LoginPage), findsNothing);
    },
  );
  testWidgets(
    'Unconfigured real mode shows a configuration error and never substitutes demo data',
    (tester) async {
      final repository = HttpDoctorWorkspaceRepository(
        baseUrl: '',
        tokenProvider: (_) async => throw StateError('Must not fetch token'),
      );
      addTearDown(repository.dispose);
      await pumpAuth(tester, repository: repository);
      expect(
        find.text('Chưa cấu hình địa chỉ HTTPS của backend bác sĩ.'),
        findsOneWidget,
      );
      expect(find.text('Dữ liệu mẫu • Chỉ để xem giao diện'), findsNothing);
      expect(find.text('06:30 - 07:30'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Expired auth removes the doctor navigator and all patient details',
    (tester) async {
      final auth = await pumpAuth(tester);
      final picker = find.byKey(const ValueKey('doctor-date-picker'));
      await tester.tap(picker);
      await tester.pumpAndSettle();
      Navigator.of(tester.element(find.byType(DatePickerDialog)))
          .pop(DateTime(2026, 10, 19));
      await tester.pumpAndSettle();
      final tile = find.text('06:30 - 07:30');
      await tester.ensureVisible(tile);
      await tester.tap(tile);
      await tester.pumpAndSettle();
      expect(find.text('Nguyễn Minh Anh'), findsOneWidget);
      await auth.logout();
      await tester.pumpAndSettle();
      expect(
        find.byType(DoctorSlotDetailsPage, skipOffstage: false),
        findsNothing,
      );
      expect(find.text('Nguyễn Minh Anh', skipOffstage: false), findsNothing);
      expect(find.byType(LoginPage), findsOneWidget);
    },
  );
  testWidgets(
    'A pushed detail route updates patient list and occupancy from the shared controller',
    (tester) async {
      final repository = TestWorkspaceRepository();
      final controller = DoctorWorkspaceController(
        repository: repository,
        userId: 'account',
        refreshInterval: null,
      );
      addTearDown(controller.dispose);
      await controller.load(day.date);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: DoctorTodayAppointmentsSection(
                state: DoctorAppointmentsDisplayState.data,
                schedules: [schedule],
                timeSlots: day.slots
                    .where((value) => value.workScheduleId == schedule.id)
                    .toList(),
                bookings: day.bookings,
                workspace: controller,
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('06:30 - 07:30'));
      await tester.pumpAndSettle();
      expect(find.text('Nguyễn Minh Anh'), findsOneWidget);
      repository.dayLoader = (_) async => DoctorDayData(
        doctor: day.doctor,
        date: day.date,
        schedules: day.schedules,
        slots: [
          for (final value in day.slots)
            TimeSlot(
              id: value.id,
              workScheduleId: value.workScheduleId,
              doctorId: value.doctorId,
              startTime: value.startTime,
              endTime: value.endTime,
              capacity: value.capacity,
              bookedCount: 0,
              status: TimeSlotStatus.available,
            ),
        ],
        bookings: [],
      );
      await controller.refresh();
      await tester.pumpAndSettle();
      expect(find.text('Nguyễn Minh Anh'), findsNothing);
      expect(find.text('Đã đặt: 0 / 3 chỗ'), findsOneWidget);
      expect(find.text('Chưa có bệnh nhân đặt ca này'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Cancelled slots and unknown capacity keep distinct truthful labels',
    (tester) async {
      for (final status in [
        TimeSlotStatus.cancelled,
        TimeSlotStatus.unavailable,
        TimeSlotStatus.available,
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: DoctorSlotDetailsPage(
              schedule: schedule,
              slot: TimeSlot(
                id: 'test',
                workScheduleId: schedule.id,
                doctorId: schedule.doctorId,
                startTime: '06:30',
                endTime: '07:30',
                status: status,
                capacity: status == TimeSlotStatus.available ? null : 3,
                bookedCount: status == TimeSlotStatus.available ? null : 3,
              ),
              bookings: [],
            ),
          ),
        );
        expect(
          find.text(
            status == TimeSlotStatus.cancelled
                ? 'Đã hủy'
                : status == TimeSlotStatus.unavailable
                ? 'Tạm ngưng'
                : 'Chưa xác định số chỗ',
          ),
          findsOneWidget,
        );
        expect(find.text('Đã đặt hết'), findsNothing);
        expect(find.text('Còn chỗ'), findsNothing);
      }
    },
  );
  testWidgets(
    'Group bookings count people and pending stays separate from waiting',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: DoctorSlotDetailsPage(
            schedule: schedule,
            slot: slot,
            bookings: [
              DoctorBooking(
                patientName: 'Nhóm ba người',
                appointment: Appointment(
                  id: 'group',
                  patientId: 'patient',
                  doctorId: schedule.doctorId,
                  workScheduleId: schedule.id,
                  timeSlotId: slot.id,
                  appointmentDate: schedule.workDate,
                  peopleCount: 3,
                  status: AppointmentStatus.pending,
                ),
              ),
            ],
          ),
        ),
      );
      final values = tester
          .widgetList<DoctorDashboardStatCard>(
            find.byType(DoctorDashboardStatCard),
          )
          .map((card) => card.value)
          .toList();
      expect(values, [3, 0, 0, 3]);
      final filter = find.widgetWithText(ChoiceChip, 'Chờ khám');
      await tester.ensureVisible(filter);
      await tester.tap(filter);
      await tester.pumpAndSettle();
      expect(find.text('Nhóm ba người'), findsNothing);
      expect(find.text('Không tìm thấy bệnh nhân'), findsOneWidget);
    },
  );
  testWidgets(
    'Account email refreshes when the authenticated profile changes',
    (tester) async {
      final repo = await pumpAuth(
        tester,
        home: const Scaffold(body: DoctorProfilePage()),
      );
      final account = find.text('Tài khoản');
      await tester.ensureVisible(account);
      await tester.tap(account);
      await tester.pumpAndSettle();
      Finder field() => find.ancestor(
        of: find.byWidgetPredicate(
          (widget) =>
              widget is TextField &&
              widget.decoration?.labelText == 'Email đăng nhập',
        ),
        matching: find.byType(TextFormField),
      );
      expect(
        tester.state<FormFieldState<String>>(field()).value,
        'old@example.test',
      );
      repo.user = testDoctor(email: 'new@example.test');
      repo.events.add('account');
      await tester.pumpAndSettle();
      expect(
        tester.state<FormFieldState<String>>(field()).value,
        'new@example.test',
      );
    },
  );
}
