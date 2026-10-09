import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_4/core/state/view_state.dart';
import 'package:flutter_application_4/features/specialties/domain/entities/specialty.dart';
import 'package:flutter_application_4/features/specialties/domain/repositories/specialty_repository.dart';
import 'package:flutter_application_4/features/specialties/presentation/controllers/specialty_controller.dart';
import 'package:flutter_application_4/features/doctors/domain/entities/doctor.dart';
import 'package:flutter_application_4/features/doctors/domain/entities/work_schedule.dart';
import 'package:flutter_application_4/features/doctors/domain/entities/time_slot.dart';
import 'package:flutter_application_4/features/doctors/domain/repositories/doctor_repository.dart';
import 'package:flutter_application_4/features/doctors/domain/repositories/work_schedule_repository.dart';
import 'package:flutter_application_4/features/doctors/domain/repositories/time_slot_repository.dart';
import 'package:flutter_application_4/features/doctors/presentation/controllers/doctor_controller.dart';
import 'package:flutter_application_4/features/doctors/presentation/controllers/schedule_controller.dart';
import 'package:flutter_application_4/features/profile/domain/entities/patient.dart';
import 'package:flutter_application_4/features/profile/domain/repositories/patient_repository.dart';
import 'package:flutter_application_4/features/profile/presentation/controllers/patient_profile_controller.dart';
import 'package:flutter_application_4/features/appointments/domain/entities/appointment.dart';
import 'package:flutter_application_4/features/appointments/domain/repositories/booking_repository.dart';
import 'package:flutter_application_4/features/appointments/domain/usecases/book_appointment.dart';
import 'package:flutter_application_4/features/appointments/presentation/controllers/appointment_controller.dart';

const specialty = Specialty(
  id: 's',
  name: 'Specialty',
  description: '',
  isActive: true,
);
const doctor = Doctor(
  id: 'd',
  userId: 'u',
  fullName: 'Doctor',
  email: '',
  phone: '',
  specialtyId: 's',
  yearsOfExperience: 1,
  consultationFee: 1,
  isActive: true,
);
const patient = Patient(
  id: 'p',
  authUserId: 'u',
  fullName: 'Patient',
  phone: '',
  email: '',
  isActive: true,
);
const slot = TimeSlot(
  id: 't',
  workScheduleId: 'w',
  doctorId: 'd',
  status: TimeSlotStatus.available,
);
const bookedSlot = TimeSlot(
  id: 'b',
  workScheduleId: 'w',
  doctorId: 'd',
  status: TimeSlotStatus.booked,
);
final date = DateTime(2026, 10, 3);
Future<void> pumpStream() => Future<void>.delayed(Duration.zero);

void main() {
  for (final outcome in ['success', 'empty', 'error']) {
    final expected = outcome == 'success'
        ? ViewState.success
        : outcome == 'empty'
        ? ViewState.empty
        : ViewState.error;
    test('specialties loading -> $outcome with live updates', () async {
      final repo = FakeSpecialties();
      final c = SpecialtyController(repo);
      addTearDown(c.dispose);
      addTearDown(repo.stream.close);
      final states = <ViewState>[];
      c.addListener(() => states.add(c.status));
      expect(c.status, ViewState.initial);
      await c.loadSpecialties();
      if (outcome == 'error') {
        repo.stream.addError(Exception('offline'));
      } else {
        repo.stream.add(outcome == 'empty' ? [] : [specialty]);
      }
      await pumpStream();
      expect(states, [ViewState.loading, expected]);
      repo.stream.add([specialty]);
      await pumpStream();
      expect(c.specialties, [specialty]);
      expect(c.status, ViewState.success);
    });
    test('doctors loading -> $outcome', () async {
      final repo = FakeDoctors()
        ..fail = outcome == 'error'
        ..values = outcome == 'empty' ? [] : [doctor];
      final c = DoctorController(repo);
      addTearDown(c.dispose);
      final states = <ViewState>[];
      c.addListener(() => states.add(c.status));
      expect(c.status, ViewState.initial);
      await c.loadDoctorsBySpecialty('s');
      expect(states, [ViewState.loading, expected]);
      expect(c.selectedSpecialtyId, 's');
      expect(repo.specialtyId, 's');
    });
    test('schedule loading -> $outcome, includes booked slots', () async {
      final repo = FakeSchedules()
        ..fail = outcome == 'error'
        ..slots = outcome == 'empty' ? [] : [slot, bookedSlot];
      final c = ScheduleController(
        workScheduleRepository: repo,
        timeSlotRepository: repo,
      );
      addTearDown(c.dispose);
      expect(c.status, ViewState.initial);
      await c.selectDate(date);
      final states = <ViewState>[];
      c.addListener(() => states.add(c.status));
      await c.selectDoctor(doctor);
      expect(states, [ViewState.loading, expected]);
      if (outcome == 'success') {
        expect(c.timeSlots.length, 2);
        expect(c.availableTimeSlots, [slot]);
      }
      if (outcome == 'error') expect(c.errorMessage, contains('offline'));
    });

    test(
      'weekly schedule loading -> $outcome is batched by date range',
      () async {
        final weeklySchedules = outcome == 'empty'
            ? <WorkSchedule>[]
            : [
                WorkSchedule(id: 'w', doctorId: 'd', workDate: date),
                WorkSchedule(
                  id: 'w-next',
                  doctorId: 'd',
                  workDate: date.add(const Duration(days: 1)),
                ),
              ];
        final repo = FakeSchedules()
          ..fail = outcome == 'error'
          ..rangeSchedules = weeklySchedules
          ..rangeSlots = outcome == 'empty'
              ? []
              : [
                  slot,
                  TimeSlot(
                    id: 't-next',
                    workScheduleId: 'w-next',
                    doctorId: 'd',
                    startTime: '09:00',
                    status: TimeSlotStatus.available,
                  ),
                ];
        final controller = ScheduleController(
          workScheduleRepository: repo,
          timeSlotRepository: repo,
        );
        addTearDown(controller.dispose);

        if (outcome == 'error') {
          await expectLater(
            controller.loadWeeklySchedulesForDoctors(
              doctors: [doctor],
              startDate: date,
              days: 5,
            ),
            throwsA(isA<Exception>()),
          );
        } else {
          final result = await controller.loadWeeklySchedulesForDoctors(
            doctors: [doctor],
            startDate: date,
            days: 5,
          );
          expect(repo.rangeScheduleRequest, (
            'd',
            date,
            date.add(const Duration(days: 4)),
          ));
          expect(
            repo.requestedWorkScheduleIds,
            weeklySchedules.map((item) => item.id).toList(),
          );
          expect(result['d']?[date], outcome == 'empty' ? isNull : [slot]);
        }
      },
    );
    test('patient loading -> $outcome', () async {
      final repo = FakePatients()
        ..fail = outcome == 'error'
        ..value = outcome == 'empty' ? null : patient;
      final c = PatientProfileController(repo);
      addTearDown(c.dispose);
      final states = <ViewState>[];
      c.addListener(() => states.add(c.status));
      expect(c.status, ViewState.initial);
      await c.loadPatient('p');
      expect(states, [ViewState.loading, expected]);
    });
    test('appointment stream loading -> $outcome', () async {
      final repo = FakeBooking();
      final c = AppointmentController(
        bookingRepository: repo,
        bookAppointmentUseCase: BookAppointment(repo),
      );
      addTearDown(c.dispose);
      addTearDown(repo.stream.close);
      expect(c.appointmentsStatus, ViewState.initial);
      c.loadAppointments('p');
      expect(c.appointmentsStatus, ViewState.loading);
      if (outcome == 'error') {
        repo.stream.addError(Exception('offline'));
      } else {
        repo.stream.add(outcome == 'empty' ? [] : [repo.result]);
      }
      await pumpStream();
      expect(c.appointmentsStatus, expected);
    });
  }
  test('old specialty response cannot overwrite a newer choice', () async {
    final repo = FakeDoctors();
    final old = Completer<List<Doctor>>();
    repo.pending = old.future;
    final c = DoctorController(repo);
    addTearDown(c.dispose);
    final first = c.loadDoctorsBySpecialty('old');
    repo.pending = null;
    repo.values = [];
    await c.selectSpecialty('new');
    old.complete([doctor]);
    await first;
    expect(c.selectedSpecialtyId, 'new');
    expect(c.doctors, isEmpty);
    expect(c.status, ViewState.empty);
  });
  test('doctor request finishing after disposal is ignored', () async {
    final repo = FakeDoctors();
    final pending = Completer<List<Doctor>>();
    repo.pending = pending.future;
    final c = DoctorController(repo);
    final request = c.loadDoctors();
    c.dispose();
    pending.complete([doctor]);
    await request;
  });
  test(
    'changing date queries new slots and clears old slots immediately',
    () async {
      final repo = FakeSchedules()..slots = [slot];
      final c = ScheduleController(
        workScheduleRepository: repo,
        timeSlotRepository: repo,
      );
      addTearDown(c.dispose);
      await c.selectDoctor(doctor);
      await c.selectDate(date);
      expect(c.timeSlots, [slot]);
      repo.slots = [];
      final request = c.selectDate(date.add(const Duration(days: 1)));
      expect(c.timeSlots, isEmpty);
      await request;
      expect(c.status, ViewState.empty);
      expect(repo.lastDate, date.add(const Duration(days: 1)));
    },
  );
  test(
    'profile update publishes saved data; update error is contained',
    () async {
      final repo = FakePatients();
      final c = PatientProfileController(repo);
      addTearDown(c.dispose);
      expect(await c.updatePatient(patient), same(patient));
      expect(c.patient, same(patient));
      expect(c.status, ViewState.success);
      repo.fail = true;
      expect(await c.updatePatient(patient), isNull);
      expect(c.status, ViewState.error);
      repo.fail = false;
      await c.refreshPatient();
      expect(c.patient, same(patient));
    },
  );
  test('booking repository failure preserves the draft for retry', () async {
    final repo = FakeBooking()..fail = true;
    final c = AppointmentController(
      bookingRepository: repo,
      bookAppointmentUseCase: BookAppointment(repo),
    );
    addTearDown(c.dispose);
    addTearDown(repo.stream.close);
    c.selectSpecialty(specialty);
    c.selectDoctor(doctor);
    c.selectDate(date);
    c.selectTimeSlot(slot);
    c.selectPatient(patient);
    final states = <ViewState>[];
    c.addListener(() => states.add(c.status));
    expect(await c.submitBooking(), isNull);
    expect(states, [ViewState.loading, ViewState.error]);
    expect(c.selectedTimeSlot, same(slot));
    expect(c.errorMessage, contains('offline'));
    repo.fail = false;
    expect(await c.submitBooking(), same(repo.result));
    expect(c.selectedTimeSlot, isNull);
  });
  test(
    'booking selections reset downstream and success resets the draft',
    () async {
      final repo = FakeBooking();
      final c = AppointmentController(
        bookingRepository: repo,
        bookAppointmentUseCase: BookAppointment(repo),
      );
      addTearDown(c.dispose);
      addTearDown(repo.stream.close);
      c.selectSpecialty(specialty);
      c.selectDoctor(doctor);
      c.selectDate(date);
      c.selectTimeSlot(slot);
      c.selectPatient(patient);
      expect(await c.submitBooking(), same(repo.result));
      expect(c.appointment, same(repo.result));
      expect(c.status, ViewState.success);
      expect(c.selectedDoctor, isNull);
      expect(c.bookingPatient, isNull);
      c.selectDoctor(doctor);
      c.selectDate(date);
      c.selectTimeSlot(slot);
      c.selectDate(date.add(const Duration(days: 1)));
      expect(c.selectedTimeSlot, isNull);
      c.resetBooking();
      expect(c.status, ViewState.initial);
    },
  );
  test(
    'invalid booking, detail and repository errors never escape to UI',
    () async {
      final repo = FakeBooking();
      final c = AppointmentController(
        bookingRepository: repo,
        bookAppointmentUseCase: BookAppointment(repo),
      );
      addTearDown(c.dispose);
      addTearDown(repo.stream.close);
      expect(await c.submitBooking(), isNull);
      expect(c.status, ViewState.error);
      expect(await c.loadAppointmentDetail('a'), same(repo.result));
      expect(c.detailStatus, ViewState.success);
      repo.fail = true;
      expect(await c.loadAppointmentDetail('missing'), isNull);
      expect(c.detailStatus, ViewState.error);
      expect(await c.saveProfile(patient), isNull);
      expect(c.status, ViewState.error);
      expect(
        await c.getAvailableSlotsForDoctorAndDate(
          doctorId: 'd',
          workDate: date,
        ),
        isEmpty,
      );
      expect(c.status, ViewState.error);
    },
  );
}

class FakeSpecialties implements SpecialtyRepository {
  final stream = StreamController<List<Specialty>>();
  @override
  Stream<List<Specialty>> watchSpecialties() => stream.stream;
}

class FakeDoctors implements DoctorRepository {
  bool fail = false;
  List<Doctor> values = [];
  String? specialtyId;
  Future<List<Doctor>>? pending;
  @override
  Future<List<Doctor>> getDoctors() async {
    if (fail) throw Exception('offline');
    return pending ?? Future.value(values);
  }

  @override
  Future<List<Doctor>> getDoctorsBySpecialty(String id) {
    specialtyId = id;
    return getDoctors();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeSchedules implements WorkScheduleRepository, TimeSlotRepository {
  bool fail = false;
  List<TimeSlot> slots = [];
  List<WorkSchedule> rangeSchedules = [];
  List<TimeSlot> rangeSlots = [];
  DateTime? lastDate;
  (String, DateTime, DateTime)? rangeScheduleRequest;
  List<String>? requestedWorkScheduleIds;
  @override
  Future<List<WorkSchedule>> getWorkSchedules({
    required String doctorId,
    DateTime? workDate,
  }) async {
    if (fail) throw Exception('offline');
    return [];
  }

  @override
  Future<List<TimeSlot>> getTimeSlotsByDoctorAndDate({
    required String doctorId,
    required DateTime workDate,
  }) async {
    lastDate = workDate;
    return slots;
  }

  @override
  Future<List<WorkSchedule>> getWorkSchedulesForDoctorsAndDateRange({
    required List<String> doctorIds,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    if (fail) throw Exception('offline');
    rangeScheduleRequest = (doctorIds.single, startDate, endDate);
    return rangeSchedules;
  }

  @override
  Future<List<TimeSlot>> getAvailableTimeSlotsByWorkScheduleIds({
    required List<String> workScheduleIds,
  }) async {
    if (fail) throw Exception('offline');
    requestedWorkScheduleIds = workScheduleIds;
    return rangeSlots;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakePatients implements PatientRepository {
  bool fail = false;
  Patient? value = patient;
  @override
  Future<Patient?> getPatientById(String id) async {
    if (fail) throw Exception('offline');
    return value;
  }

  @override
  Future<Patient> updatePatient(Patient value) async {
    if (fail) throw Exception('offline');
    this.value = value;
    return value;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeBooking implements BookingRepository {
  bool fail = false;
  final stream = StreamController<List<Appointment>>.broadcast();
  final result = const Appointment(
    id: 'a',
    patientId: 'p',
    doctorId: 'd',
    workScheduleId: 'w',
    timeSlotId: 't',
    status: AppointmentStatus.pending,
  );
  @override
  Stream<List<Appointment>> watchAppointmentsByPatient(String id) =>
      stream.stream;
  @override
  Future<Appointment> bookAppointment(Appointment value) async {
    if (fail) throw Exception('offline');
    return result;
  }

  @override
  Future<Appointment> getAppointmentById(String id) async {
    if (fail) throw Exception('missing');
    return result;
  }

  @override
  Future<Patient> savePatient(Patient value) async {
    if (fail) throw Exception('offline');
    return value;
  }

  @override
  Future<List<TimeSlot>> getAvailableTimeSlotsByDoctorAndDate({
    required String doctorId,
    required DateTime workDate,
  }) async {
    if (fail) throw Exception('offline');
    return [slot];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
