import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_4/core/state/view_state.dart';
import 'package:flutter_application_4/features/admin/domain/repositories/admin_account_repository.dart';
import 'package:flutter_application_4/features/admin/presentation/controllers/admin_account_controller.dart';
import 'package:flutter_application_4/features/admin/presentation/controllers/admin_appointment_controller.dart';
import 'package:flutter_application_4/features/appointments/domain/entities/appointment.dart';
import 'package:flutter_application_4/features/appointments/domain/repositories/appointment_repository.dart';
import 'package:flutter_application_4/features/auth/data/models/user_model.dart';
import 'package:flutter_application_4/features/auth/domain/entities/user_entity.dart';
import 'package:flutter_application_4/features/doctors/domain/entities/doctor.dart';
import 'package:flutter_application_4/features/doctors/domain/entities/time_slot.dart';
import 'package:flutter_application_4/features/doctors/domain/entities/work_schedule.dart';
import 'package:flutter_application_4/features/doctors/domain/repositories/doctor_repository.dart';
import 'package:flutter_application_4/features/doctors/domain/repositories/time_slot_repository.dart';
import 'package:flutter_application_4/features/doctors/domain/repositories/work_schedule_repository.dart';

const _doctor = Doctor(
  id: 'doctor-1',
  userId: 'user-doctor-1',
  fullName: 'Bác sĩ An',
  email: '',
  phone: '',
  specialtyId: 'specialty-1',
  yearsOfExperience: 3,
  consultationFee: 100000,
  isActive: true,
);

const _account = UserModel(
  id: 'patient-user-1',
  email: 'patient@example.com',
  fullName: 'Người bệnh',
  phone: '0900000000',
  role: UserRole.patient,
  isActive: false,
  status: 'PENDING',
);

void main() {
  test(
    'account workflow approves once and keeps pending stream live',
    () async {
      final repository = _Accounts();
      final controller = AdminAccountController(repository);
      addTearDown(controller.dispose);
      addTearDown(repository.close);

      await controller.loadPendingAccounts();
      repository.addPending([_account]);
      await Future<void>.delayed(Duration.zero);
      expect(controller.pendingAccounts, [_account]);
      expect(controller.status, ViewState.success);

      final approved = await controller.approveAccount(_account.id);
      expect(approved?.status, 'APPROVED');
      expect(approved?.role, UserRole.patient);
      expect(controller.status, ViewState.success);
      expect(await controller.approveAccount(_account.id), isNull);
      expect(controller.status, ViewState.error);

      repository.addPending(const []);
      await Future<void>.delayed(Duration.zero);
      expect(controller.pendingAccounts, isEmpty);
      expect(controller.status, ViewState.empty);
    },
  );

  test(
    'appointment filtering returns records and flags a broken relation',
    () async {
      final appointments = _Appointments();
      final controller = AdminAppointmentController(
        appointmentRepository: appointments,
        doctorRepository: _Doctors(),
        workScheduleRepository: _Schedules(),
        timeSlotRepository: _Slots(),
      );
      addTearDown(controller.dispose);
      addTearDown(appointments.close);

      final load = controller.load(
        filter: const AdminAppointmentFilter(status: AppointmentStatus.pending),
      );
      appointments.add([
        _appointment('valid'),
        _appointment('broken', timeSlotId: 'missing-slot'),
        _appointment('ignored', status: AppointmentStatus.completed),
      ]);
      await load;

      expect(controller.status, ViewState.success);
      expect(controller.records, hasLength(2));
      expect(
        controller.invalidRelationshipRecords.single.appointment.id,
        'broken',
      );
    },
  );
}

Appointment _appointment(
  String id, {
  String timeSlotId = 'slot-1',
  AppointmentStatus status = AppointmentStatus.pending,
}) => Appointment(
  id: id,
  patientId: 'patient-1',
  doctorId: _doctor.id,
  workScheduleId: 'schedule-1',
  timeSlotId: timeSlotId,
  appointmentDate: DateTime(2026, 10, 21),
  startTime: '08:00',
  endTime: '09:00',
  peopleCount: 1,
  status: status,
);

class _Accounts implements AdminAccountRepository {
  final _pending = StreamController<List<UserModel>>.broadcast();
  bool reviewed = false;
  void addPending(List<UserModel> values) => _pending.add(values);
  Future<void> close() => _pending.close();
  @override
  Stream<List<UserModel>> watchPendingAccounts() => _pending.stream;
  @override
  Stream<List<UserModel>> watchApprovedAccounts() => const Stream.empty();
  @override
  Future<UserModel> approveAccount(String accountId) async {
    if (reviewed) throw StateError('already reviewed');
    reviewed = true;
    return const UserModel(
      id: 'patient-user-1',
      email: 'patient@example.com',
      fullName: 'Người bệnh',
      phone: '0900000000',
      role: UserRole.patient,
      isActive: true,
      status: 'APPROVED',
    );
  }

  @override
  Future<UserModel> rejectAccount(String accountId) =>
      throw UnimplementedError();
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
  @override
  Future<Doctor?> getDoctorById(String doctorId) async =>
      doctorId == _doctor.id ? _doctor : null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Schedules implements WorkScheduleRepository {
  @override
  Future<List<WorkSchedule>> getWorkSchedules({
    required String doctorId,
    DateTime? workDate,
  }) async => [
    WorkSchedule(
      id: 'schedule-1',
      doctorId: _doctor.id,
      workDate: DateTime(2026, 10, 21),
      startTime: '08:00',
      endTime: '12:00',
    ),
  ];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Slots implements TimeSlotRepository {
  @override
  Future<List<TimeSlot>> getTimeSlotsByWorkSchedule(
    String workScheduleId,
  ) async => const [
    TimeSlot(
      id: 'slot-1',
      workScheduleId: 'schedule-1',
      doctorId: 'doctor-1',
      startTime: '08:00',
      endTime: '09:00',
      capacity: 5,
      bookedCount: 1,
      status: TimeSlotStatus.available,
    ),
  ];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
