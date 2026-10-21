import '../entities/appointment.dart';

/// Creates, reads and updates appointments.
abstract class AppointmentRepository {
  Stream<List<Appointment>> watchAppointmentsByPatient(String patientId);

  /// Streams every appointment for the admin dashboard.
  ///
  /// Non-production implementations can opt out safely; the dashboard will
  /// show an empty appointment set until they provide this stream.
  Stream<List<Appointment>> watchAllAppointments() => Stream.value(const []);

  /// Streams appointments for the currently authenticated doctor profile.
  Stream<List<Appointment>> watchAppointmentsByDoctor(String doctorId);

  Future<Appointment> getAppointmentById(String appointmentId);

  /// Atomically creates an appointment and reserves its time slot.
  Future<Appointment> createAppointment(Appointment appointment);

  /// Updates an existing appointment only; it must never create one.
  Future<Appointment> updateAppointment(Appointment appointment);

  /// Cancels an appointment and frees up its time slot.
  Future<Appointment> cancelAppointment(
    String appointmentId,
    String cancellationReason,
  );

  /// Reschedules an appointment to a new time slot.
  Future<Appointment> rescheduleAppointment(
    String appointmentId,
    String newWorkScheduleId,
    String newTimeSlotId,
    DateTime newDate,
    String newStartTime,
    String newEndTime,
  );
}
