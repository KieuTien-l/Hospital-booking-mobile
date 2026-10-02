import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/models/appointment_model.dart';
import '../../../../core/models/doctor_model.dart';
import '../../../../core/models/patient_model.dart';
import '../../../../core/models/specialty_model.dart';
import '../../../../core/models/time_slot_model.dart';
import '../../../../core/models/work_schedule_model.dart';
import '../../domain/repositories/patient_booking_repository.dart';
import 'firebase_appointment_repository.dart';
import 'firebase_doctor_repository.dart';
import 'firebase_patient_repository.dart';
import 'firebase_specialty_repository.dart';
import 'firebase_time_slot_repository.dart';
import 'firebase_work_schedule_repository.dart';

/// Compatibility facade for the existing patient screens.
///
/// Data access is implemented by the six focused repositories. New code should
/// depend on those repositories directly; this facade keeps existing provider
/// and use-case wiring stable while the UI is migrated incrementally.
class FirebasePatientBookingRepository implements PatientBookingRepository {
  FirebasePatientBookingRepository({FirebaseFirestore? firestore})
    : _specialtyRepository = FirebaseSpecialtyRepository(firestore: firestore),
      _doctorRepository = FirebaseDoctorRepository(firestore: firestore),
      _workScheduleRepository = FirebaseWorkScheduleRepository(
        firestore: firestore,
      ),
      _timeSlotRepository = FirebaseTimeSlotRepository(firestore: firestore),
      _appointmentRepository = FirebaseAppointmentRepository(
        firestore: firestore,
      ),
      _patientRepository = FirebasePatientRepository(firestore: firestore);

  final FirebaseSpecialtyRepository _specialtyRepository;
  final FirebaseDoctorRepository _doctorRepository;
  final FirebaseWorkScheduleRepository _workScheduleRepository;
  final FirebaseTimeSlotRepository _timeSlotRepository;
  final FirebaseAppointmentRepository _appointmentRepository;
  final FirebasePatientRepository _patientRepository;

  @override
  Stream<List<Specialty>> watchSpecialties() =>
      _specialtyRepository.watchSpecialties();

  @override
  Future<List<Doctor>> getDoctorsBySpecialty(String specialtyId) =>
      _doctorRepository.getDoctorsBySpecialty(specialtyId);

  @override
  Future<List<WorkSchedule>> getWorkSchedules({
    required String doctorId,
    required DateTime workDate,
  }) => _workScheduleRepository.getWorkSchedules(
    doctorId: doctorId,
    workDate: workDate,
  );

  @override
  Future<List<TimeSlot>> getAvailableTimeSlots(String workScheduleId) =>
      _timeSlotRepository.getAvailableTimeSlots(workScheduleId);

  @override
  Future<List<TimeSlot>> getTimeSlotsByDoctorAndDate({
    required String doctorId,
    required DateTime workDate,
  }) => _timeSlotRepository.getTimeSlotsByDoctorAndDate(
    doctorId: doctorId,
    workDate: workDate,
  );

  /// Direct query used by booking flows after the patient selects a date.
  @override
  Future<List<TimeSlot>> getAvailableTimeSlotsByDoctorAndDate({
    required String doctorId,
    required DateTime workDate,
  }) => _timeSlotRepository.getAvailableTimeSlotsByDoctorAndDate(
    doctorId: doctorId,
    workDate: workDate,
  );

  @override
  Stream<Patient?> watchPatientByAuthUser(String authUserId) =>
      _patientRepository.watchPatientByAuthUser(authUserId);

  @override
  Future<Patient> savePatient(Patient patient) {
    return patient.id.trim().isEmpty
        ? _patientRepository.createPatient(patient)
        : _patientRepository.updatePatient(patient);
  }

  @override
  Stream<List<Appointment>> watchAppointmentsByPatient(String patientId) =>
      _appointmentRepository.watchAppointmentsByPatient(patientId);

  @override
  Future<Appointment> getAppointmentById(String appointmentId) =>
      _appointmentRepository.getAppointmentById(appointmentId);

  @override
  Future<Appointment> bookAppointment(Appointment appointment) =>
      _appointmentRepository.createAppointment(appointment);
}
