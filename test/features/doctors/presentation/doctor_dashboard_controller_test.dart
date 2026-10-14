import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_4/core/state/view_state.dart';
import 'package:flutter_application_4/features/appointments/domain/entities/appointment.dart';
import 'package:flutter_application_4/features/appointments/domain/repositories/appointment_repository.dart';
import 'package:flutter_application_4/features/doctors/domain/entities/doctor.dart';
import 'package:flutter_application_4/features/doctors/domain/entities/work_schedule.dart';
import 'package:flutter_application_4/features/doctors/domain/repositories/doctor_repository.dart';
import 'package:flutter_application_4/features/doctors/domain/repositories/work_schedule_repository.dart';
import 'package:flutter_application_4/features/doctors/presentation/controllers/doctor_dashboard_controller.dart';

const _doctor = Doctor(
  id: 'doctor-1',
  userId: 'auth-doctor-1',
  fullName: 'Bác sĩ An',
  email: '',
  phone: '',
  specialtyId: 'specialty-1',
  yearsOfExperience: 5,
  consultationFee: 200000,
  isActive: true,
);

void main() {
  test('loads the signed-in doctor schedule and derives dashboard counts',
      () async {
    final appointments = _Appointments();
    final controller = DoctorDashboardController(
      doctorRepository: _Doctors(_doctor),
      workScheduleRepository: _Schedules([
        WorkSchedule(
          id: 'schedule-1',
          doctorId: _doctor.id,
          workDate: DateTime(2026, 10, 14),
        ),
      ]),
      appointmentRepository: appointments,
    );
    addTearDown(controller.dispose);
    addTearDown(appointments.close);

    await controller.load(
      authUserId: _doctor.userId,
      selectedDate: DateTime(2026, 10, 14),
    );
    appointments.add([
      _appointment('pending', AppointmentStatus.pending, peopleCount: 2),
      _appointment('completed', AppointmentStatus.completed),
      _appointment('cancelled', AppointmentStatus.cancelled),
      _appointment(
        'other-day',
        AppointmentStatus.confirmed,
        date: DateTime(2026, 10, 15),
      ),
    ]);
    await Future<void>.delayed(Duration.zero);

    expect(controller.status, ViewState.success);
    expect(controller.workSchedules, hasLength(1));
    expect(controller.bookedCount, 3);
    expect(controller.completedCount, 1);
    expect(controller.waitingCount, 2);
  });

  test('returns an empty dashboard when no doctor profile belongs to the user',
      () async {
    final appointments = _Appointments();
    final controller = DoctorDashboardController(
      doctorRepository: _Doctors(null),
      workScheduleRepository: _Schedules(const []),
      appointmentRepository: appointments,
    );
    addTearDown(controller.dispose);
    addTearDown(appointments.close);

    await controller.load(
      authUserId: 'unknown-user',
      selectedDate: DateTime(2026, 10, 14),
    );

    expect(controller.status, ViewState.empty);
    expect(controller.doctor, isNull);
    expect(controller.workSchedules, isEmpty);
    expect(controller.appointments, isEmpty);
  });
}

Appointment _appointment(
  String id,
  AppointmentStatus status, {
  int peopleCount = 1,
  DateTime? date,
}) => Appointment(
  id: id,
  patientId: 'patient-1',
  doctorId: _doctor.id,
  workScheduleId: 'schedule-1',
  timeSlotId: 'slot-$id',
  appointmentDate: date ?? DateTime(2026, 10, 14),
  peopleCount: peopleCount,
  status: status,
);

class _Doctors implements DoctorRepository {
  _Doctors(this.value);

  final Doctor? value;

  @override
  Future<Doctor?> getDoctorByUserId(String userId) async => value;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Schedules implements WorkScheduleRepository {
  _Schedules(this.values);

  final List<WorkSchedule> values;

  @override
  Future<List<WorkSchedule>> getWorkSchedules({
    required String doctorId,
    DateTime? workDate,
  }) async => values;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Appointments implements AppointmentRepository {
  final _stream = StreamController<List<Appointment>>.broadcast();

  void add(List<Appointment> values) => _stream.add(values);

  Future<void> close() => _stream.close();

  @override
  Stream<List<Appointment>> watchAppointmentsByDoctor(String doctorId) =>
      _stream.stream;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
