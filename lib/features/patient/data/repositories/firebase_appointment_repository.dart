import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/models/appointment_model.dart';
import '../../../../core/models/doctor_model.dart';
import '../../../../core/models/time_slot_model.dart';
import '../../../../core/models/work_schedule_model.dart';
import '../../domain/exceptions/booking_exception.dart';
import '../../domain/repositories/appointment_repository.dart';

/// Firestore-backed appointment repository for the LICH_HEN collection.
class FirebaseAppointmentRepository implements AppointmentRepository {
  FirebaseAppointmentRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _appointments =>
      _firestore.collection(Appointment.collectionName);
  CollectionReference<Map<String, dynamic>> get _timeSlots =>
      _firestore.collection(TimeSlot.collectionName);
  CollectionReference<Map<String, dynamic>> get _workSchedules =>
      _firestore.collection(WorkSchedule.collectionName);
  CollectionReference<Map<String, dynamic>> get _doctors =>
      _firestore.collection(Doctor.collectionName);

  @override
  Stream<List<Appointment>> watchAppointmentsByPatient(String patientId) {
    final normalizedId = patientId.trim();
    if (normalizedId.isEmpty) return Stream.value(const []);

    return _appointments
        .where('patientId', isEqualTo: normalizedId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(Appointment.fromFirestore)
              .toList(growable: false),
        );
  }

  @override
  Future<Appointment> getAppointmentById(String appointmentId) async {
    final normalizedId = appointmentId.trim();
    if (normalizedId.isEmpty) {
      throw const BookingException('An appointment id is required.');
    }

    final snapshot = await _appointments.doc(normalizedId).get();
    if (!snapshot.exists) {
      throw const BookingException('The requested appointment does not exist.');
    }
    return Appointment.fromFirestore(snapshot);
  }

  @override
  Future<Appointment> createAppointment(Appointment appointment) async {
    _validateNewAppointment(appointment);

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
      if (newBookedCount > slot.capacity!) {
        throw const BookingException(
          'The selected time slot does not have enough remaining capacity.',
        );
      }
      final nextSlotStatus = newBookedCount >= slot.capacity!
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

  @override
  Future<Appointment> updateAppointment(Appointment appointment) async {
    final appointmentId = appointment.id.trim();
    if (appointmentId.isEmpty) {
      throw const BookingException('An appointment id is required to update.');
    }

    final document = _appointments.doc(appointmentId);
    if (!(await document.get()).exists) {
      throw const BookingException('The requested appointment does not exist.');
    }
    await document.update(appointment.toFirestore());
    return appointment;
  }

  void _validateNewAppointment(Appointment appointment) {
    if (appointment.patientId.trim().isEmpty ||
        appointment.doctorId.trim().isEmpty ||
        appointment.workScheduleId.trim().isEmpty ||
        appointment.timeSlotId.trim().isEmpty) {
      throw const BookingException(
        'Patient, doctor, schedule and time slot are required.',
      );
    }
    if (appointment.peopleCount < 1) {
      throw const BookingException('At least one patient must be booked.');
    }
  }
}
