import '../../domain/entities/appointment.dart';
import '../../../doctors/domain/entities/doctor.dart';
import '../../../profile/domain/entities/patient.dart';
import '../../../specialties/domain/entities/specialty.dart';
import '../../../doctors/domain/entities/time_slot.dart';
import '../../../doctors/domain/entities/work_schedule.dart';
import '../../domain/repositories/booking_repository.dart';
import '../../domain/repositories/appointment_repository.dart';
import '../../../doctors/domain/repositories/doctor_repository.dart';
import '../../../profile/domain/repositories/patient_repository.dart';
import '../../../specialties/domain/repositories/specialty_repository.dart';
import '../../../doctors/domain/repositories/time_slot_repository.dart';
import '../../../doctors/domain/repositories/work_schedule_repository.dart';

/// Coordinates repositories needed by the profile and appointment flow.
class BookingRepositoryImpl implements BookingRepository {
  BookingRepositoryImpl({
    required this.specialtyRepository,
    required this.doctorRepository,
    required this.workScheduleRepository,
    required this.timeSlotRepository,
    required this.appointmentRepository,
    required this.patientRepository,
  });

  final SpecialtyRepository specialtyRepository;
  final DoctorRepository doctorRepository;
  final WorkScheduleRepository workScheduleRepository;
  final TimeSlotRepository timeSlotRepository;
  final AppointmentRepository appointmentRepository;
  final PatientRepository patientRepository;

  @override
  Stream<List<Specialty>> watchSpecialties() =>
      specialtyRepository.watchSpecialties();

  @override
  Future<List<Doctor>> getDoctorsBySpecialty(String specialtyId) =>
      doctorRepository.getDoctorsBySpecialty(specialtyId);

  @override
  Future<List<WorkSchedule>> getWorkSchedules({
    required String doctorId,
    required DateTime workDate,
  }) => workScheduleRepository.getWorkSchedules(
    doctorId: doctorId,
    workDate: workDate,
  );

  @override
  Future<List<TimeSlot>> getAvailableTimeSlots(String workScheduleId) =>
      timeSlotRepository.getAvailableTimeSlots(workScheduleId);

  @override
  Future<List<TimeSlot>> getTimeSlotsByDoctorAndDate({
    required String doctorId,
    required DateTime workDate,
  }) => timeSlotRepository.getTimeSlotsByDoctorAndDate(
    doctorId: doctorId,
    workDate: workDate,
  );

  /// Direct query used by booking flows after the patient selects a date.
  @override
  Future<List<TimeSlot>> getAvailableTimeSlotsByDoctorAndDate({
    required String doctorId,
    required DateTime workDate,
  }) => timeSlotRepository.getAvailableTimeSlotsByDoctorAndDate(
    doctorId: doctorId,
    workDate: workDate,
  );

  @override
  Stream<Patient?> watchPatientByAuthUser(String authUserId) =>
      patientRepository.watchPatientByAuthUser(authUserId);

  @override
  Future<Patient> savePatient(Patient patient) {
    return patient.id.trim().isEmpty
        ? patientRepository.createPatient(patient)
        : patientRepository.updatePatient(patient);
  }

  @override
  Stream<List<Appointment>> watchAppointmentsByPatient(String patientId) =>
      appointmentRepository.watchAppointmentsByPatient(patientId);

  @override
  Future<Appointment> getAppointmentById(String appointmentId) =>
      appointmentRepository.getAppointmentById(appointmentId);

  @override
  Future<Appointment> bookAppointment(Appointment appointment) =>
      appointmentRepository.createAppointment(appointment);
}
