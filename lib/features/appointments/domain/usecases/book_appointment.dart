import '../entities/appointment.dart';
import '../exceptions/booking_exception.dart';
import '../repositories/booking_repository.dart';

/// Validates a booking request before handing the atomic reservation to the
/// repository.
class BookAppointment {
  const BookAppointment(this._repository);

  final BookingRepository _repository;

  Future<Appointment> call({
    required String patientId,
    required String doctorId,
    required String workScheduleId,
    required String timeSlotId,
    DateTime? appointmentDate,
    String? startTime,
    String? endTime,
    String? reason,
    String? note,
    String? symptoms,
    int peopleCount = 1,
  }) {
    if (patientId.trim().isEmpty ||
        doctorId.trim().isEmpty ||
        workScheduleId.trim().isEmpty ||
        timeSlotId.trim().isEmpty) {
      throw const BookingException(
        'Patient, doctor, schedule and time slot are required.',
      );
    }
    if (peopleCount < 1) {
      throw const BookingException('At least one patient must be booked.');
    }

    return _repository.bookAppointment(
      Appointment(
        id: '',
        patientId: patientId.trim(),
        doctorId: doctorId.trim(),
        workScheduleId: workScheduleId.trim(),
        timeSlotId: timeSlotId.trim(),
        appointmentDate: appointmentDate,
        startTime: startTime,
        endTime: endTime,
        status: AppointmentStatus.pending,
        reason: reason?.trim().isEmpty ?? true ? null : reason!.trim(),
        note: note?.trim().isEmpty ?? true ? null : note!.trim(),
        symptoms: symptoms?.trim().isEmpty ?? true ? null : symptoms!.trim(),
        peopleCount: peopleCount,
      ),
    );
  }
}
