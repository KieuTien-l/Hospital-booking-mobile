import '../entities/appointment.dart';
import '../../../doctors/domain/entities/doctor.dart';
import '../../../profile/domain/entities/patient.dart';
import '../../../specialties/domain/entities/specialty.dart';
import '../../../doctors/domain/entities/time_slot.dart';
import '../../../doctors/domain/entities/work_schedule.dart';

/// Data operations required by the patient profile and appointment flow.
///
/// The interface is Firebase-agnostic so presentation and business logic can
/// be tested without a Firestore instance.
abstract class BookingRepository {
  Stream<List<Specialty>> watchSpecialties();

  Future<List<Doctor>> getDoctorsBySpecialty(String specialtyId);

  Future<List<WorkSchedule>> getWorkSchedules({
    required String doctorId,
    required DateTime workDate,
  });

  Future<List<TimeSlot>> getAvailableTimeSlots(String workScheduleId);

  Future<List<TimeSlot>> getTimeSlotsByDoctorAndDate({
    required String doctorId,
    required DateTime workDate,
  });

  /// Resolves a doctor's work schedule for a day and returns only its
  /// available slots. An empty list means there is no matching schedule/slot.
  Future<List<TimeSlot>> getAvailableTimeSlotsByDoctorAndDate({
    required String doctorId,
    required DateTime workDate,
  });

  Stream<Patient?> watchPatientByAuthUser(String authUserId);

  Future<Patient> savePatient(Patient patient);

  Stream<List<Appointment>> watchAppointmentsByPatient(String patientId);

  /// Retrieves one appointment for the appointment-detail screen.
  ///
  /// Implementations throw a domain-specific exception when no appointment
  /// exists for [appointmentId].
  Future<Appointment> getAppointmentById(String appointmentId);

  /// Atomically creates an appointment and marks its slot as booked.
  Future<Appointment> bookAppointment(Appointment appointment);

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
