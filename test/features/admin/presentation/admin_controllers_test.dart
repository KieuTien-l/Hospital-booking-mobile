import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_4/core/state/view_state.dart';
import 'package:flutter_application_4/features/admin/domain/repositories/admin_management_repository.dart';
import 'package:flutter_application_4/features/admin/presentation/controllers/admin_dashboard_controller.dart';
import 'package:flutter_application_4/features/admin/presentation/controllers/admin_management_controller.dart';
import 'package:flutter_application_4/features/appointments/domain/entities/appointment.dart';
import 'package:flutter_application_4/features/appointments/domain/repositories/appointment_repository.dart';
import 'package:flutter_application_4/features/doctors/domain/entities/doctor.dart';
import 'package:flutter_application_4/features/doctors/domain/entities/time_slot.dart';
import 'package:flutter_application_4/features/doctors/domain/entities/work_schedule.dart';
import 'package:flutter_application_4/features/doctors/domain/repositories/doctor_repository.dart';
import 'package:flutter_application_4/features/specialties/domain/entities/specialty.dart';
import 'package:flutter_application_4/features/specialties/domain/repositories/specialty_repository.dart';

const _specialty = Specialty(
  id: 'specialty-1',
  name: 'Nội tổng quát',
  description: '',
  isActive: true,
);
const _doctor = Doctor(
  id: 'doctor-1',
  userId: 'doctor-user-1',
  fullName: 'Bác sĩ An',
  email: '',
  phone: '',
  specialtyId: 'specialty-1',
  yearsOfExperience: 4,
  consultationFee: 100000,
  isActive: true,
);

void main() {
  test(
    'ADM-02 empty sources return empty state and zero real counts',
    () async {
      final specialties = _Specialties(), appointments = _Appointments();
      final controller = AdminDashboardController(
        specialtyRepository: specialties,
        doctorRepository: _Doctors([]),
        appointmentRepository: appointments,
      );
      addTearDown(controller.dispose);
      addTearDown(specialties.close);
      addTearDown(appointments.close);
      final load = controller.load();
      specialties.add([]);
      appointments.add([]);
      await load;
      expect(controller.status, ViewState.empty);
      expect(controller.appointmentCount, 0);
      expect(controller.activeDoctorCount, 0);
    },
  );

  test('ADM-02 revoked access clears counts and unrelated events cannot hide the error', () async {
    final specialties = _Specialties(), appointments = _Appointments();
    final controller = AdminDashboardController(
      specialtyRepository: specialties,
      doctorRepository: _Doctors([_doctor]),
      appointmentRepository: appointments,
    );
    addTearDown(controller.dispose);
    addTearDown(specialties.close);
    addTearDown(appointments.close);
    final load = controller.load();
    specialties.add([_specialty]);
    appointments.add([_appointment('one', AppointmentStatus.pending)]);
    await load;
    specialties.addError(Exception('permission-denied'));
    await Future<void>.delayed(Duration.zero);
    appointments.add([_appointment('two', AppointmentStatus.completed)]);
    await Future<void>.delayed(Duration.zero);
    expect(controller.status, ViewState.error);
    expect(controller.specialties, isEmpty);
    expect(controller.doctors, isEmpty);
    expect(controller.appointments, isEmpty);
  });

  test('dashboard loads real values, receives updates and refreshes', () async {
    final specialties = _Specialties();
    final appointments = _Appointments();
    final controller = AdminDashboardController(
      specialtyRepository: specialties,
      doctorRepository: _Doctors([_doctor]),
      appointmentRepository: appointments,
    );
    addTearDown(controller.dispose);
    addTearDown(specialties.close);
    addTearDown(appointments.close);

    final load = controller.load();
    specialties.add([_specialty]);
    appointments.add([_appointment('first', AppointmentStatus.pending)]);
    await load;

    expect(controller.status, ViewState.success);
    expect(controller.specialtyCount, 1);
    expect(controller.activeDoctorCount, 1);
    expect(controller.appointmentCount, 1);
    expect(controller.pendingAppointmentCount, 1);

    appointments.add([
      _appointment('first', AppointmentStatus.pending),
      _appointment('second', AppointmentStatus.completed),
    ]);
    await Future<void>.delayed(Duration.zero);
    expect(controller.appointmentCount, 2);

    final refresh = controller.refresh();
    await Future<void>.delayed(Duration.zero);
    specialties.add([_specialty]);
    appointments.add([_appointment('second', AppointmentStatus.completed)]);
    await refresh;
    expect(controller.status, ViewState.success);
    expect(controller.pendingAppointmentCount, 0);
  });

  test('dashboard exposes stream failures as an error state', () async {
    final specialties = _Specialties();
    final appointments = _Appointments();
    final controller = AdminDashboardController(
      specialtyRepository: specialties,
      doctorRepository: _Doctors(const []),
      appointmentRepository: appointments,
    );
    addTearDown(controller.dispose);
    addTearDown(specialties.close);
    addTearDown(appointments.close);

    final load = controller.load();
    specialties.addError(Exception('offline'));
    await load;

    expect(controller.status, ViewState.error);
    expect(controller.errorMessage, contains('offline'));
  });

  test(
    'management controller returns transfer result and contains errors',
    () async {
      final repository = _ManagementRepository();
      final controller = AdminManagementController(repository);
      addTearDown(controller.dispose);

      final moved = await controller.transferDoctorToSpecialty(
        doctorId: _doctor.id,
        targetSpecialtyId: 'specialty-2',
      );
      expect(moved?.specialtyId, 'specialty-2');
      expect(repository.transferRequest, (_doctor.id, 'specialty-2'));
      expect(controller.status, ViewState.success);
      expect(controller.lastOperation, 'doctor transfer');

      repository.fail = true;
      expect(await controller.saveDoctor(_doctor), isNull);
      expect(controller.status, ViewState.error);
    },
  );
}

Appointment _appointment(String id, AppointmentStatus status) => Appointment(
  id: id,
  patientId: 'patient-1',
  doctorId: _doctor.id,
  workScheduleId: 'schedule-1',
  timeSlotId: 'slot-$id',
  status: status,
);

class _Specialties implements SpecialtyRepository {
  final _stream = StreamController<List<Specialty>>.broadcast();
  void add(List<Specialty> values) => _stream.add(values);
  void addError(Object error) => _stream.addError(error);
  Future<void> close() => _stream.close();
  @override
  Stream<List<Specialty>> watchAllSpecialties() => _stream.stream;
  @override
  Stream<List<Specialty>> watchSpecialties() => _stream.stream;
}

class _Appointments implements AppointmentRepository {
  final _stream = StreamController<List<Appointment>>.broadcast();
  void add(List<Appointment> values) => _stream.add(values);
  Future<void> close() => _stream.close();
  @override
  Stream<List<Appointment>> watchAllAppointments() => _stream.stream;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Doctors implements DoctorRepository {
  _Doctors(this.values);
  final List<Doctor> values;
  @override
  Future<List<Doctor>> getAllDoctors() async => values;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ManagementRepository implements AdminManagementRepository {
  bool fail = false;
  (String, String)? transferRequest;
  void _check() {
    if (fail) throw Exception('save failed');
  }

  @override
  Future<Doctor> saveDoctor(Doctor doctor) async {
    _check();
    return doctor;
  }

  @override
  Future<Specialty> saveSpecialty(Specialty specialty) async {
    _check();
    return specialty;
  }

  @override
  Future<WorkSchedule> saveWorkSchedule(WorkSchedule schedule) async {
    _check();
    return schedule;
  }

  @override
  Future<TimeSlot> saveTimeSlot(TimeSlot timeSlot) async {
    _check();
    return timeSlot;
  }

  @override
  Future<Doctor> transferDoctorToSpecialty({
    required String doctorId,
    required String targetSpecialtyId,
  }) async {
    _check();
    transferRequest = (doctorId, targetSpecialtyId);
    return Doctor(
      id: _doctor.id,
      userId: _doctor.userId,
      fullName: _doctor.fullName,
      email: _doctor.email,
      phone: _doctor.phone,
      specialtyId: targetSpecialtyId,
      yearsOfExperience: _doctor.yearsOfExperience,
      consultationFee: _doctor.consultationFee,
      isActive: _doctor.isActive,
    );
  }
}
