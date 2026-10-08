import '../../domain/entities/appointment.dart';
import '../../domain/repositories/appointment_repository.dart';
import '../datasources/appointment_firebase_datasource.dart';

class AppointmentRepositoryImpl implements AppointmentRepository {
  AppointmentRepositoryImpl(AppointmentFirebaseDatasource datasource)
    : _datasource = datasource;

  final AppointmentFirebaseDatasource _datasource;

  @override
  Stream<List<Appointment>> watchAppointmentsByPatient(String patientId) =>
      _datasource.watchAppointmentsByPatient(patientId);

  @override
  Future<Appointment> getAppointmentById(String appointmentId) =>
      _datasource.getAppointmentById(appointmentId);

  @override
  Future<Appointment> createAppointment(Appointment appointment) =>
      _datasource.createAppointment(appointment);

  @override
  Future<Appointment> updateAppointment(Appointment appointment) =>
      _datasource.updateAppointment(appointment);

  @override
  Future<Appointment> cancelAppointment(
    String appointmentId,
    String cancellationReason,
  ) => _datasource.cancelAppointment(appointmentId, cancellationReason);

  @override
  Future<Appointment> rescheduleAppointment(
    String appointmentId,
    String newWorkScheduleId,
    String newTimeSlotId,
    DateTime newDate,
    String newStartTime,
    String newEndTime,
  ) => _datasource.rescheduleAppointment(
    appointmentId: appointmentId,
    newWorkScheduleId: newWorkScheduleId,
    newTimeSlotId: newTimeSlotId,
    newDate: newDate,
    newStartTime: newStartTime,
    newEndTime: newEndTime,
  );
}
