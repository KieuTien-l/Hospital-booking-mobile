import 'package:flutter_application_4/features/appointments/domain/entities/appointment.dart';
import 'package:flutter_application_4/features/doctors/domain/entities/doctor.dart';
import 'package:flutter_application_4/features/profile/domain/entities/patient.dart';
import 'package:flutter_application_4/features/specialties/domain/entities/specialty.dart';
import 'package:flutter_application_4/features/doctors/domain/entities/time_slot.dart';
import 'package:flutter_application_4/features/doctors/domain/entities/work_schedule.dart';
import 'package:flutter_application_4/features/appointments/domain/exceptions/booking_exception.dart';
import 'package:flutter_application_4/features/appointments/domain/repositories/booking_repository.dart';
import 'package:flutter_application_4/features/appointments/domain/usecases/book_appointment.dart';
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

class _FakePatientBookingRepository implements BookingRepository {
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
