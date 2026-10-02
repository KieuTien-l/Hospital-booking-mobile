import 'package:flutter_application_4/core/models/appointment_model.dart';
import 'package:flutter_application_4/core/models/doctor_model.dart';
import 'package:flutter_application_4/core/models/patient_model.dart';
import 'package:flutter_application_4/core/models/specialty_model.dart';
import 'package:flutter_application_4/core/models/time_slot_model.dart';
import 'package:flutter_application_4/core/models/work_schedule_model.dart';
import 'package:flutter_application_4/features/patient/domain/exceptions/booking_exception.dart';
import 'package:flutter_application_4/features/patient/domain/repositories/patient_booking_repository.dart';
import 'package:flutter_application_4/features/patient/domain/usecases/book_appointment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BookAppointment', () {
    test(
      'creates a pending appointment with the selected relationships',
      () async {
        final repository = _FakePatientBookingRepository();
        final useCase = BookAppointment(repository);

        final appointment = await useCase(
          patientId: 'bn-1',
          doctorId: 'bs-1',
          workScheduleId: 'llv-1',
          timeSlotId: 'ck-1',
          reason: 'Kham dinh ky',
        );

        expect(appointment.status, AppointmentStatus.pending);
        expect(appointment.patientId, 'bn-1');
        expect(appointment.doctorId, 'bs-1');
        expect(repository.bookedAppointment, same(appointment));
      },
    );

    test('rejects a request with a missing relationship id', () {
      final useCase = BookAppointment(_FakePatientBookingRepository());

      expect(
        () => useCase(
          patientId: '',
          doctorId: 'bs-1',
          workScheduleId: 'llv-1',
          timeSlotId: 'ck-1',
        ),
        throwsA(isA<BookingException>()),
      );
    });
  });
}

class _FakePatientBookingRepository implements PatientBookingRepository {
  Appointment? bookedAppointment;

  @override
  Future<Appointment> bookAppointment(Appointment appointment) async {
    bookedAppointment = appointment;
    return appointment;
  }

  @override
  Future<List<Doctor>> getDoctorsBySpecialty(String specialtyId) {
    throw UnimplementedError();
  }

  @override
  Future<List<TimeSlot>> getAvailableTimeSlots(String workScheduleId) {
    throw UnimplementedError();
  }

  @override
  Future<List<TimeSlot>> getAvailableTimeSlotsByDoctorAndDate({
    required String doctorId,
    required DateTime workDate,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<TimeSlot>> getTimeSlotsByDoctorAndDate({
    required String doctorId,
    required DateTime workDate,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Appointment> getAppointmentById(String appointmentId) {
    throw UnimplementedError();
  }

  @override
  Future<List<WorkSchedule>> getWorkSchedules({
    required String doctorId,
    required DateTime workDate,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Patient> savePatient(Patient patient) {
    throw UnimplementedError();
  }

  @override
  Stream<List<Appointment>> watchAppointmentsByPatient(String patientId) {
    return const Stream.empty();
  }

  @override
  Stream<Patient?> watchPatientByAuthUser(String authUserId) {
    return const Stream.empty();
  }

  @override
  Stream<List<Specialty>> watchSpecialties() {
    return const Stream.empty();
  }
}
