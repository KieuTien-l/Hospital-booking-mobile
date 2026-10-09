import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_4/core/themes/app_theme.dart';
import 'package:flutter_application_4/features/doctors/domain/entities/doctor.dart';
import 'package:flutter_application_4/features/doctors/domain/entities/time_slot.dart';
import 'package:flutter_application_4/features/doctors/domain/entities/work_schedule.dart';
import 'package:flutter_application_4/features/doctors/domain/repositories/doctor_repository.dart';
import 'package:flutter_application_4/features/doctors/domain/repositories/time_slot_repository.dart';
import 'package:flutter_application_4/features/doctors/domain/repositories/work_schedule_repository.dart';
import 'package:flutter_application_4/features/doctors/presentation/controllers/schedule_controller.dart';
import 'package:flutter_application_4/features/appointments/presentation/pages/select_appointment_time_page.dart';
import 'package:flutter_application_4/features/appointments/presentation/models/appointment_time_demo_data.dart';
import 'package:flutter_application_4/features/appointments/presentation/models/appointment_time_ui_models.dart';
import 'package:flutter_application_4/features/appointments/presentation/widgets/appointment_date_strip.dart';
import 'package:flutter_application_4/features/appointments/presentation/widgets/appointment_time_slot_grid.dart';
import 'package:flutter_application_4/features/specialties/domain/entities/specialty.dart';
import 'package:flutter_application_4/features/appointments/presentation/widgets/appointment_doctor_card.dart';
import 'package:flutter_application_4/features/doctors/presentation/pages/doctor_detail_page.dart';
import 'package:flutter_application_4/features/appointments/presentation/pages/appointment_information_page.dart';
import 'package:flutter_application_4/features/appointments/presentation/pages/booking_review_page.dart';
import 'package:flutter_application_4/features/appointments/presentation/controllers/appointment_controller.dart';
import 'package:flutter_application_4/features/appointments/domain/entities/appointment.dart';
import 'package:flutter_application_4/features/appointments/domain/repositories/booking_repository.dart';
import 'package:flutter_application_4/features/appointments/domain/usecases/book_appointment.dart';
import 'package:flutter_application_4/features/profile/domain/entities/patient.dart';

const specialty = Specialty(
  id: 'skin',
  name: 'Da liễu',
  description: '',
  isActive: true,
);

void main() {
  Future<void> showPage(
    WidgetTester tester, {
    Size size = const Size(412, 915),
    double scale = 1,
    List<AppointmentDoctorOption>? doctors,
    ValueChanged<AppointmentTimeSelection>? onContinue,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: SelectAppointmentTimePage(
          specialty: specialty,
          initialDate: DateTime(2026, 10, 9),
          doctors:
              doctors ?? AppointmentTimeDemoData.doctors(DateTime(2026, 10, 9)),
          onContinue: onContinue,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> reveal(WidgetTester tester, Finder finder) async {
    final vertical = find
        .byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              widget.axisDirection == AxisDirection.down,
        )
        .first;
    if (finder.evaluate().isEmpty) {
      tester.state<ScrollableState>(vertical).position.jumpTo(0);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(finder, 180, scrollable: vertical);
    }
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
  }

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await reveal(tester, finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('Unavailable slots are disabled and continue returns selection', (
    tester,
  ) async {
    AppointmentTimeSelection? selection;
    await showPage(tester, onContinue: (value) => selection = value);
    await reveal(tester, find.byKey(const ValueKey('continue-time')));
    expect(
      tester
          .widget<ElevatedButton>(find.byKey(const ValueKey('continue-time')))
          .onPressed,
      isNull,
    );
    await reveal(tester, find.byKey(const ValueKey('slot-morning-1')));
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const ValueKey('slot-morning-1')))
          .onPressed,
      isNull,
    );
    await tapVisible(tester, find.byKey(const ValueKey('slot-morning-5')));
    await tapVisible(tester, find.byKey(const ValueKey('continue-time')));
    expect(selection!.doctor.id, 'demo-morning');
    expect(selection!.date, DateTime(2026, 10, 9));
    expect(selection!.slot.id, 'morning-5');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Only one global slot; changing date clears it and supports empty schedule',
    (tester) async {
      await showPage(tester);
      await tapVisible(tester, find.byKey(const ValueKey('slot-morning-5')));
      await tapVisible(
        tester,
        find.byKey(const ValueKey('expand-demo-afternoon')),
      );
      await tapVisible(tester, find.byKey(const ValueKey('slot-afternoon-1')));
      final grids = tester
          .widgetList<AppointmentTimeSlotGrid>(
            find.byType(AppointmentTimeSlotGrid),
          )
          .toList();
      expect(grids.where((grid) => grid.selectedId != null), hasLength(1));
      expect(grids.last.selectedId, 'afternoon-1');
      final strip = find.byType(AppointmentDateStrip).last;
      await tapVisible(
        tester,
        find.descendant(of: strip, matching: find.text('23/10')),
      );
      expect(
        tester
            .widget<ElevatedButton>(find.byKey(const ValueKey('continue-time')))
            .onPressed,
        isNull,
      );
      expect(
        find.text('Không có khung giờ khám trong ngày này.'),
        findsOneWidget,
      );
      expect(
        tester
            .widgetList<AppointmentDateStrip>(find.byType(AppointmentDateStrip))
            .every((strip) => strip.selected == DateTime(2026, 10, 23)),
        isTrue,
      );
      await tapVisible(
        tester,
        find.byKey(const ValueKey('expand-demo-afternoon')),
      );
      expect(find.byType(AppointmentTimeSlotGrid), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Doctor detail opens matching identity and preserves booking UI on back',
    (tester) async {
      AppointmentTimeSelection? selection;
      await showPage(tester, onContinue: (value) => selection = value);
      final firstStrip = tester.widget<AppointmentDateStrip>(
        find.byType(AppointmentDateStrip).first,
      );
      firstStrip.onSelected(DateTime(2026, 10, 16));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.byKey(const ValueKey('slot-morning-5')));
      for (final id in ['demo-morning', 'demo-afternoon']) {
        await reveal(
          tester,
          find.byWidgetPredicate(
            (widget) =>
                widget is AppointmentDoctorCard && widget.doctor.id == id,
          ),
        );
        final card = find.byWidgetPredicate(
          (widget) => widget is AppointmentDoctorCard && widget.doctor.id == id,
        );
        final expected = tester.widget<AppointmentDoctorCard>(card).doctor;
        await tapVisible(
          tester,
          find.descendant(of: card, matching: find.byType(TextButton)),
        );
        final detail = tester.widget<DoctorDetailPage>(
          find.byType(DoctorDetailPage),
        );
        expect(detail.doctor.id, expected.id);
        expect(detail.doctor.name, expected.name);
        expect(detail.doctor.specialty, specialty.name);
        expect(detail.doctor.schedule.single.session, expected.session);
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(find.byType(DoctorDetailPage), findsNothing);
        expect(
          tester
              .widgetList<AppointmentDateStrip>(
                find.byType(AppointmentDateStrip),
              )
              .every((strip) => strip.selected == DateTime(2026, 10, 16)),
          isTrue,
        );
      }
      await tapVisible(tester, find.byKey(const ValueKey('continue-time')));
      expect(selection!.doctor.id, 'demo-morning');
      expect(selection!.date, DateTime(2026, 10, 16));
      expect(selection!.slot.id, 'morning-5');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Continue opens confirmation and back preserves selected time', (
    tester,
  ) async {
    await showPage(tester);
    await tapVisible(tester, find.byKey(const ValueKey('slot-morning-5')));
    await tapVisible(tester, find.byKey(const ValueKey('continue-time')));
    final information = tester
        .widget<ConfirmAppointmentPage>(find.byType(ConfirmAppointmentPage))
        .information;
    expect(information.specialtyName, specialty.name);
    expect(information.selection.doctor.id, 'demo-morning');
    expect(information.selection.date, DateTime(2026, 10, 9));
    expect(information.selection.slot.id, 'morning-5');
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await reveal(tester, find.byType(AppointmentTimeSlotGrid));
    expect(
      tester
          .widget<AppointmentTimeSlotGrid>(find.byType(AppointmentTimeSlotGrid))
          .selectedId,
      'morning-5',
    );
    await tapVisible(tester, find.byKey(const ValueKey('continue-time')));
    expect(find.byType(ConfirmAppointmentPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Empty doctors stays empty', (tester) async {
    await showPage(tester, doctors: []);
    expect(
      find.text('Chưa có bác sĩ và lịch khám để hiển thị.'),
      findsOneWidget,
    );
    expect(find.byType(AppointmentTimeSlotGrid), findsNothing);
    expect(
      tester
          .widget<ElevatedButton>(find.byKey(const ValueKey('continue-time')))
          .onPressed,
      isNull,
    );
  });

  testWidgets(
    'Loads five-day availability for all specialty doctors in batch',
    (tester) async {
      final startDate = DateTime(2026, 10, 9);
      final doctors = _LiveDoctors();
      final schedules = _LiveSchedules(startDate);
      final controller = ScheduleController(
        workScheduleRepository: schedules,
        timeSlotRepository: schedules,
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<DoctorRepository>.value(value: doctors),
            ChangeNotifierProvider<ScheduleController>.value(value: controller),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: SelectAppointmentTimePage(
              specialty: specialty,
              initialDate: startDate,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(doctors.requestedSpecialtyId, specialty.id);
      expect(schedules.rangeRequest?.$1, ['doctor-1', 'doctor-2']);
      expect(schedules.rangeRequest?.$2, startDate);
      expect(
        schedules.rangeRequest?.$3,
        startDate.add(const Duration(days: 4)),
      );
      expect(schedules.requestedWorkScheduleIds, ['schedule-1']);
      expect(find.byType(AppointmentDoctorCard), findsNWidgets(2));
      expect(find.byKey(const ValueKey('slot-live-1')), findsOneWidget);
      expect(
        tester
            .widget<AppointmentDateStrip>(find.byType(AppointmentDateStrip))
            .dates,
        List.generate(5, (index) => startDate.add(Duration(days: index))),
      );
    },
  );

  testWidgets('Live selection keeps the confirmation UI with real IDs', (
    tester,
  ) async {
    final startDate = DateTime(2026, 10, 9);
    final doctors = _LiveDoctors();
    final schedules = _LiveSchedules(startDate);
    final scheduleController = ScheduleController(
      workScheduleRepository: schedules,
      timeSlotRepository: schedules,
    );
    final bookingRepository = _LiveBookingRepository();
    final appointmentController = AppointmentController(
      bookingRepository: bookingRepository,
      bookAppointmentUseCase: BookAppointment(bookingRepository),
    );
    addTearDown(scheduleController.dispose);
    addTearDown(appointmentController.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<DoctorRepository>.value(value: doctors),
          ChangeNotifierProvider<ScheduleController>.value(
            value: scheduleController,
          ),
          ChangeNotifierProvider<AppointmentController>.value(
            value: appointmentController,
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            settings: const RouteSettings(
              arguments: Patient(
                id: 'patient-1',
                authUserId: 'user-1',
                fullName: 'Nguyễn Minh An',
                phone: '0900000123',
                email: 'patient@example.com',
                isActive: true,
              ),
            ),
            builder: (_) => SelectAppointmentTimePage(
              specialty: specialty,
              initialDate: startDate,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tapVisible(tester, find.byKey(const ValueKey('slot-live-1')));
    await tapVisible(tester, find.byKey(const ValueKey('continue-time')));

    final page = tester.widget<ConfirmAppointmentPage>(
      find.byType(ConfirmAppointmentPage),
    );
    expect(page.information.selection.doctor.id, 'doctor-1');
    expect(page.information.selection.slot.workScheduleId, 'schedule-1');
    expect(page.information.selection.slot.id, 'live-1');
    expect(page.information.selection.slot.startTime, '08:00');
    expect(page.onSubmitBooking, isNotNull);

    await tapVisible(tester, find.byKey(const ValueKey('health-yes')));
    await tapVisible(tester, find.byKey(const ValueKey('private-no')));
    await tapVisible(
      tester,
      find.byKey(const ValueKey('continue-confirmation')),
    );
    expect(find.byType(BookingReviewPage), findsOneWidget);
    await tapVisible(
      tester,
      find.byKey(const ValueKey('confirm-booking-review')),
    );
    await tester.pumpAndSettle();
    expect(bookingRepository.booked?.patientId, 'patient-1');
    expect(bookingRepository.booked?.doctorId, 'doctor-1');
    expect(bookingRepository.booked?.workScheduleId, 'schedule-1');
    expect(bookingRepository.booked?.timeSlotId, 'live-1');
  });

  for (final size in [const Size(412, 915), const Size(320, 700)]) {
    testWidgets('Layout and horizontal dates at $size with large text', (
      tester,
    ) async {
      await showPage(tester, size: size, scale: 1.5);
      await tapVisible(
        tester,
        find.byKey(const ValueKey('expand-demo-afternoon')),
      );
      final strip = find.byType(AppointmentDateStrip).last;
      await tester.ensureVisible(strip);
      await tester.drag(
        find.descendant(
          of: strip,
          matching: find.byType(SingleChildScrollView),
        ),
        const Offset(-350, 0),
      );
      await tester.pumpAndSettle();
      await reveal(tester, find.byKey(const ValueKey('continue-time')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}

class _LiveDoctors implements DoctorRepository {
  String? requestedSpecialtyId;

  @override
  Future<List<Doctor>> getDoctorsBySpecialty(String specialtyId) async {
    requestedSpecialtyId = specialtyId;
    return const [
      Doctor(
        id: 'doctor-1',
        userId: 'user-1',
        fullName: 'Nguyễn Văn A',
        email: '',
        phone: '',
        specialtyId: 'skin',
        yearsOfExperience: 8,
        consultationFee: 150000,
        isActive: true,
        qualification: 'BSCKII',
      ),
      Doctor(
        id: 'doctor-2',
        userId: 'user-2',
        fullName: 'Trần Thị B',
        email: '',
        phone: '',
        specialtyId: 'skin',
        yearsOfExperience: 5,
        consultationFee: 120000,
        isActive: true,
      ),
    ];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _LiveSchedules implements WorkScheduleRepository, TimeSlotRepository {
  _LiveSchedules(this.startDate);

  final DateTime startDate;
  (List<String>, DateTime, DateTime)? rangeRequest;
  List<String>? requestedWorkScheduleIds;

  @override
  Future<List<WorkSchedule>> getWorkSchedulesForDoctorsAndDateRange({
    required List<String> doctorIds,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    rangeRequest = (doctorIds, startDate, endDate);
    return [
      WorkSchedule(
        id: 'schedule-1',
        doctorId: 'doctor-1',
        workDate: this.startDate,
      ),
    ];
  }

  @override
  Future<List<TimeSlot>> getAvailableTimeSlotsByWorkScheduleIds({
    required List<String> workScheduleIds,
  }) async {
    requestedWorkScheduleIds = workScheduleIds;
    return const [
      TimeSlot(
        id: 'live-1',
        workScheduleId: 'schedule-1',
        doctorId: 'doctor-1',
        startTime: '08:00',
        endTime: '08:30',
        status: TimeSlotStatus.available,
      ),
    ];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _LiveBookingRepository implements BookingRepository {
  Appointment? booked;

  @override
  Future<Appointment> bookAppointment(Appointment appointment) async {
    booked = appointment;
    return appointment;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
