import '../../../../core/models/appointment_model.dart';
import '../../../../core/models/doctor_model.dart';
import '../../../../core/models/patient_model.dart';
import '../../../../core/models/specialty_model.dart';
import '../../../../core/models/time_slot_model.dart';
import '../../../../core/models/work_schedule_model.dart';

/// Data operations required by the patient profile and appointment flow.
///
/// The interface is Firebase-agnostic so presentation and business logic can
/// be tested without a Firestore instance.
abstract class PatientBookingRepository {
  Stream<List<Specialty>> watchSpecialties();

  Future<List<Doctor>> getDoctorsBySpecialty(String specialtyId);

  Future<List<WorkSchedule>> getWorkSchedules({
    required String doctorId,
    required DateTime workDate,
  });

  Future<List<TimeSlot>> getAvailableTimeSlots(String workScheduleId);

  Stream<Patient?> watchPatientByAuthUser(String authUserId);

  Future<Patient> savePatient(Patient patient);

  Stream<List<Appointment>> watchAppointmentsByPatient(String patientId);

  /// Atomically creates an appointment and marks its slot as booked.
  Future<Appointment> bookAppointment(Appointment appointment);
}
