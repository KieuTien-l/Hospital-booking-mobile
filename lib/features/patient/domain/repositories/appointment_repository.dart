import '../../../../core/models/appointment_model.dart';

/// Creates, reads and updates appointments.
abstract class AppointmentRepository {
  Stream<List<Appointment>> watchAppointmentsByPatient(String patientId);

  Future<Appointment> getAppointmentById(String appointmentId);

  /// Atomically creates an appointment and reserves its time slot.
  Future<Appointment> createAppointment(Appointment appointment);

  /// Updates an existing appointment only; it must never create one.
  Future<Appointment> updateAppointment(Appointment appointment);
}
