import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/models/appointment_model.dart';
import '../../../../core/models/doctor_model.dart';
import '../../../../core/models/patient_model.dart';
import '../../../../core/models/specialty_model.dart';
import '../../../../core/models/time_slot_model.dart';
import '../../../../core/models/work_schedule_model.dart';
import '../../domain/exceptions/booking_exception.dart';
import '../../domain/repositories/patient_booking_repository.dart';

/// Firestore implementation for patient profile and booking data.
class FirebasePatientBookingRepository implements PatientBookingRepository {
  FirebasePatientBookingRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _specialties =>
      _firestore.collection(Specialty.collectionName);
  CollectionReference<Map<String, dynamic>> get _doctors =>
      _firestore.collection(Doctor.collectionName);
  CollectionReference<Map<String, dynamic>> get _workSchedules =>
      _firestore.collection(WorkSchedule.collectionName);
  CollectionReference<Map<String, dynamic>> get _timeSlots =>
      _firestore.collection(TimeSlot.collectionName);
  CollectionReference<Map<String, dynamic>> get _appointments =>
      _firestore.collection(Appointment.collectionName);
  CollectionReference<Map<String, dynamic>> get _patients =>
      _firestore.collection(Patient.collectionName);

  @override
  Stream<List<Specialty>> watchSpecialties() {
    return _specialties.snapshots().map(
      (snapshot) => snapshot.docs
          .map(Specialty.fromFirestore)
          .where((specialty) => specialty.isActive)
          .toList(growable: false),
    );
  }

  @override
  Future<List<Doctor>> getDoctorsBySpecialty(String specialtyId) async {
    final snapshot = await _doctors
        .where('specialtyId', isEqualTo: specialtyId)
        .get();
    return snapshot.docs
        .map(Doctor.fromFirestore)
        .where((doctor) => doctor.isActive)
        .toList(growable: false);
  }

  @override
  Future<List<WorkSchedule>> getWorkSchedules({
    required String doctorId,
    required DateTime workDate,
  }) async {
    final snapshot = await _workSchedules
        .where('doctorId', isEqualTo: doctorId)
        .get();
    return snapshot.docs
        .map(WorkSchedule.fromFirestore)
        .where((schedule) => _isSameDate(schedule.workDate, workDate))
        .where((schedule) => schedule.status.toUpperCase() == 'ACTIVE')
        .toList(growable: false);
  }

  @override
  Future<List<TimeSlot>> getAvailableTimeSlots(String workScheduleId) async {
    final snapshot = await _timeSlots
        .where('workScheduleId', isEqualTo: workScheduleId)
        .get();
    return snapshot.docs
        .map(TimeSlot.fromFirestore)
        .where((slot) => slot.isAvailable)
        .toList(growable: false);
  }

  @override
  Stream<Patient?> watchPatientByAuthUser(String authUserId) {
    return _patients
        .where('authUserId', isEqualTo: authUserId)
        .limit(1)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.isEmpty
              ? null
              : Patient.fromFirestore(snapshot.docs.first),
        );
  }

  @override
  Future<Patient> savePatient(Patient patient) async {
    if (patient.authUserId.trim().isEmpty) {
      throw const BookingException(
        'A Firebase user id is required for a patient profile.',
      );
    }

    final document = patient.id.trim().isEmpty
        ? _patients.doc()
        : _patients.doc(patient.id.trim());
    final savedPatient = Patient(
      id: document.id,
      authUserId: patient.authUserId.trim(),
      fullName: patient.fullName.trim(),
      phone: patient.phone.trim(),
      email: patient.email.trim(),
      isActive: patient.isActive,
      dateOfBirth: patient.dateOfBirth,
      gender: patient.gender,
      address: patient.address,
      avatarUrl: patient.avatarUrl,
      insuranceNumber: patient.insuranceNumber,
      ethnicity: patient.ethnicity,
      occupation: patient.occupation,
      ward: patient.ward,
      district: patient.district,
      province: patient.province,
      country: patient.country,
      nationalId: patient.nationalId,
      relationshipToAccountHolder: patient.relationshipToAccountHolder,
      status: patient.status,
      createdAt: patient.createdAt,
      updatedAt: patient.updatedAt,
    );
    final existing = await document.get();
    await document.set(
      existing.exists
          ? savedPatient.toFirestore()
          : savedPatient.toFirestoreCreate(),
      SetOptions(merge: true),
    );
    return savedPatient;
  }

  @override
  Stream<List<Appointment>> watchAppointmentsByPatient(String patientId) {
    return _appointments
        .where('patientId', isEqualTo: patientId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(Appointment.fromFirestore)
              .toList(growable: false),
        );
  }

  @override
  Future<Appointment> bookAppointment(Appointment appointment) async {
    _validateAppointment(appointment);

    final appointmentDocument = _appointments.doc();
    final slotDocument = _timeSlots.doc(appointment.timeSlotId);
    final scheduleDocument = _workSchedules.doc(appointment.workScheduleId);
    final doctorDocument = _doctors.doc(appointment.doctorId);

    return _firestore.runTransaction((transaction) async {
      final slotSnapshot = await transaction.get(slotDocument);
      final scheduleSnapshot = await transaction.get(scheduleDocument);
      final doctorSnapshot = await transaction.get(doctorDocument);
      if (!slotSnapshot.exists ||
          !scheduleSnapshot.exists ||
          !doctorSnapshot.exists) {
        throw const BookingException(
          'The selected schedule or time slot no longer exists.',
        );
      }

      final slot = TimeSlot.fromFirestore(slotSnapshot);
      final schedule = WorkSchedule.fromFirestore(scheduleSnapshot);
      final doctor = Doctor.fromFirestore(doctorSnapshot);
      if (!slot.isAvailable) {
        throw const BookingException('This time slot is no longer available.');
      }
      if (!doctor.isActive) {
        throw const BookingException('This doctor is no longer available.');
      }
      if (slot.workScheduleId != appointment.workScheduleId ||
          slot.doctorId != appointment.doctorId ||
          schedule.doctorId != appointment.doctorId) {
        throw const BookingException(
          'The selected booking information is inconsistent.',
        );
      }
      if (schedule.workDate == null ||
          slot.startTime == null ||
          slot.endTime == null ||
          slot.capacity == null ||
          slot.capacity! < 1 ||
          doctor.specialtyId.isEmpty) {
        throw const BookingException(
          'The selected schedule is incomplete. Please choose another slot.',
        );
      }

      final newBookedCount = (slot.bookedCount ?? 0) + appointment.peopleCount;
      if (slot.capacity != null && newBookedCount > slot.capacity!) {
        throw const BookingException(
          'The selected time slot does not have enough remaining capacity.',
        );
      }
      final nextSlotStatus =
          slot.capacity != null && newBookedCount >= slot.capacity!
          ? TimeSlotStatus.booked
          : TimeSlotStatus.available;
      final savedAppointment = Appointment(
        id: appointmentDocument.id,
        patientId: appointment.patientId,
        doctorId: appointment.doctorId,
        workScheduleId: appointment.workScheduleId,
        timeSlotId: appointment.timeSlotId,
        specialtyId: appointment.specialtyId ?? doctor.specialtyId,
        appointmentDate: appointment.appointmentDate ?? schedule.workDate,
        startTime: appointment.startTime ?? slot.startTime,
        endTime: appointment.endTime ?? slot.endTime,
        bookedAt: appointment.bookedAt ?? DateTime.now(),
        status: AppointmentStatus.pending,
        reason: appointment.reason,
        note: appointment.note,
        cancellationReason: appointment.cancellationReason,
        symptoms: appointment.symptoms ?? appointment.reason,
        peopleCount: appointment.peopleCount,
        queueNumber: appointment.queueNumber,
        checkInTime: appointment.checkInTime,
        qrCode: appointment.qrCode,
      );
      transaction.set(appointmentDocument, {
        ...savedAppointment.toFirestore(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      transaction.update(slotDocument, {
        'bookedCount': newBookedCount,
        'status': nextSlotStatus.firestoreValue,
        'appointmentId': appointmentDocument.id,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return savedAppointment;
    });
  }

  bool _isSameDate(DateTime? source, DateTime target) {
    return source != null &&
        source.year == target.year &&
        source.month == target.month &&
        source.day == target.day;
  }

  void _validateAppointment(Appointment appointment) {
    if (appointment.patientId.isEmpty ||
        appointment.doctorId.isEmpty ||
        appointment.workScheduleId.isEmpty ||
        appointment.timeSlotId.isEmpty) {
      throw const BookingException(
        'Patient, doctor, schedule and time slot are required.',
      );
    }
    if (appointment.peopleCount < 1) {
      throw const BookingException('At least one patient must be booked.');
    }
  }
}
