import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/appointment_model.dart';
import '../../../doctors/data/models/doctor_model.dart';
import '../../../doctors/data/models/time_slot_model.dart';
import '../../../doctors/data/models/work_schedule_model.dart';
import '../../domain/exceptions/booking_exception.dart';

/// Firestore-backed appointment repository for the LICH_HEN collection.
class AppointmentFirebaseDatasource {
  AppointmentFirebaseDatasource({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _appointments =>
      _firestore.collection(AppointmentModel.collectionName);
  CollectionReference<Map<String, dynamic>> get _timeSlots =>
      _firestore.collection(TimeSlotModel.collectionName);
  CollectionReference<Map<String, dynamic>> get _workSchedules =>
      _firestore.collection(WorkScheduleModel.collectionName);
  CollectionReference<Map<String, dynamic>> get _doctors =>
      _firestore.collection(DoctorModel.collectionName);

  Stream<List<Appointment>> watchAppointmentsByPatient(String patientId) {
    final normalizedId = patientId.trim();
    if (normalizedId.isEmpty) return Stream.value(const []);

    return _appointments
        .where('patientId', isEqualTo: normalizedId)
        .snapshots()
        .map(
          (snapshot) {
            final appointments = snapshot.docs
                .map(AppointmentModel.fromFirestore)
                .toList();
            // Avoid requiring a composite Firestore index for a basic patient
            // feed, while still giving the UI a deterministic newest-first list.
            appointments.sort((a, b) {
              final aDate = a.appointmentDate ?? a.bookedAt ?? a.createdAt;
              final bDate = b.appointmentDate ?? b.bookedAt ?? b.createdAt;
              return (bDate ?? DateTime(0)).compareTo(aDate ?? DateTime(0));
            });
            return List.unmodifiable(appointments);
          },
        );
  }

  Future<Appointment> getAppointmentById(String appointmentId) async {
    final normalizedId = appointmentId.trim();
    if (normalizedId.isEmpty) {
      throw const BookingException('An appointment id is required.');
    }
    final snapshot = await _appointments.doc(normalizedId).get();
    if (!snapshot.exists) {
      throw const BookingException('The requested appointment does not exist.');
    }
    return AppointmentModel.fromFirestore(snapshot);
  }

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

      final slot = TimeSlotModel.fromFirestore(slotSnapshot);
      final schedule = WorkScheduleModel.fromFirestore(scheduleSnapshot);
      final doctor = DoctorModel.fromFirestore(doctorSnapshot);
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
      if (appointment.appointmentDate != null &&
          !_isSameDate(appointment.appointmentDate!, schedule.workDate!)) {
        throw const BookingException(
          'The selected date does not match the selected schedule.',
        );
      }
      if ((appointment.startTime != null &&
              appointment.startTime != slot.startTime) ||
          (appointment.endTime != null && appointment.endTime != slot.endTime)) {
        throw const BookingException(
          'The selected time does not match the selected time slot.',
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
      final reservationCounts = Map<String, int>.from(slot.reservationCounts)
        ..[appointmentDocument.id] = appointment.peopleCount;
      final savedAppointment = AppointmentModel(
        id: appointmentDocument.id,
        patientId: appointment.patientId,
        doctorId: appointment.doctorId,
        workScheduleId: appointment.workScheduleId,
        timeSlotId: appointment.timeSlotId,
        specialtyId: appointment.specialtyId ?? doctor.specialtyId,
        appointmentDate: schedule.workDate,
        startTime: slot.startTime,
        endTime: slot.endTime,
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
        'reservationCounts': reservationCounts,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return savedAppointment;
    });
  }

  Future<Appointment> updateAppointment(Appointment appointment) async {
    final appointmentId = appointment.id.trim();
    if (appointmentId.isEmpty) {
      throw const BookingException('An appointment id is required to update.');
    }

    final document = _appointments.doc(appointmentId);
    if (!(await document.get()).exists) {
      throw const BookingException('The requested appointment does not exist.');
    }
    await document.update(
      AppointmentModel.fromEntity(appointment).toFirestore(),
    );
    return appointment;
  }

  Future<Appointment> cancelAppointment(
    String appointmentId,
    String cancellationReason,
  ) async {
    final normalizedId = appointmentId.trim();
    if (normalizedId.isEmpty) {
      throw const BookingException('An appointment id is required.');
    }
    if (cancellationReason.trim().isEmpty) {
      throw const BookingException('A cancellation reason is required.');
    }

    final appointmentRef = _appointments.doc(normalizedId);

    return _firestore.runTransaction((transaction) async {
      final appSnapshot = await transaction.get(appointmentRef);
      if (!appSnapshot.exists) {
        throw const BookingException('The appointment does not exist.');
      }

      final appointment = AppointmentModel.fromFirestore(appSnapshot);
      if (appointment.status != AppointmentStatus.pending &&
          appointment.status != AppointmentStatus.confirmed) {
        throw const BookingException(
          'Only pending or confirmed appointments can be cancelled.',
        );
      }

      final slotRef = _timeSlots.doc(appointment.timeSlotId);
      final slotSnapshot = await transaction.get(slotRef);

      transaction.update(appointmentRef, {
        'status': AppointmentStatus.cancelled.firestoreValue,
        'cancellationReason': cancellationReason.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (slotSnapshot.exists) {
        final slot = TimeSlotModel.fromFirestore(slotSnapshot);
        final currentCount = slot.bookedCount ?? 1;
        final newCount = (currentCount - appointment.peopleCount)
            .clamp(0, slot.capacity ?? 9999)
            .toInt();
        final reservationCounts = Map<String, int>.from(slot.reservationCounts)
          ..remove(appointment.id);

        transaction.update(slotRef, {
          'bookedCount': newCount,
          'status': _slotStatusFor(newCount, slot.capacity).firestoreValue,
          'appointmentId': appointment.id,
          'reservationCounts': reservationCounts,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      return AppointmentModel(
        id: appointment.id,
        patientId: appointment.patientId,
        doctorId: appointment.doctorId,
        workScheduleId: appointment.workScheduleId,
        timeSlotId: appointment.timeSlotId,
        specialtyId: appointment.specialtyId,
        appointmentDate: appointment.appointmentDate,
        startTime: appointment.startTime,
        endTime: appointment.endTime,
        bookedAt: appointment.bookedAt,
        status: AppointmentStatus.cancelled,
        reason: appointment.reason,
        note: appointment.note,
        cancellationReason: cancellationReason.trim(),
        symptoms: appointment.symptoms,
        peopleCount: appointment.peopleCount,
        queueNumber: appointment.queueNumber,
        checkInTime: appointment.checkInTime,
        qrCode: appointment.qrCode,
        createdAt: appointment.createdAt,
        updatedAt: DateTime.now(),
      );
    });
  }

  Future<Appointment> rescheduleAppointment({
    required String appointmentId,
    required String newWorkScheduleId,
    required String newTimeSlotId,
    required DateTime newDate,
    required String newStartTime,
    required String newEndTime,
  }) async {
    final normalizedId = appointmentId.trim();
    if (normalizedId.isEmpty) {
      throw const BookingException('An appointment id is required.');
    }

    final appointmentRef = _appointments.doc(normalizedId);
    final newSlotRef = _timeSlots.doc(newTimeSlotId);
    final newScheduleRef = _workSchedules.doc(newWorkScheduleId);

    return _firestore.runTransaction((transaction) async {
      final appSnapshot = await transaction.get(appointmentRef);
      if (!appSnapshot.exists) {
        throw const BookingException('The appointment does not exist.');
      }
      final appointment = AppointmentModel.fromFirestore(appSnapshot);
      if (appointment.status == AppointmentStatus.cancelled ||
          appointment.status == AppointmentStatus.completed ||
          appointment.status == AppointmentStatus.noShow) {
        throw const BookingException(
          'Cannot reschedule a cancelled or completed appointment.',
        );
      }

      if (appointment.timeSlotId == newTimeSlotId) {
        throw const BookingException(
          'Please choose a different time slot to reschedule.',
        );
      }

      final oldSlotRef = _timeSlots.doc(appointment.timeSlotId);
      final oldSlotSnapshot = await transaction.get(oldSlotRef);

      final newSlotSnapshot = await transaction.get(newSlotRef);
      final newScheduleSnapshot = await transaction.get(newScheduleRef);

      if (!newSlotSnapshot.exists || !newScheduleSnapshot.exists) {
        throw const BookingException(
          'The new schedule or time slot no longer exists.',
        );
      }

      final newSlot = TimeSlotModel.fromFirestore(newSlotSnapshot);
      final newSchedule = WorkScheduleModel.fromFirestore(newScheduleSnapshot);
      final newScheduleDate = newSchedule.workDate;
      if (!newSlot.isAvailable) {
        throw const BookingException(
          'The new time slot is no longer available.',
        );
      }
      if (newSchedule.status.toUpperCase() != 'ACTIVE' ||
          newSchedule.doctorId != appointment.doctorId ||
          newSlot.doctorId != appointment.doctorId ||
          newSlot.workScheduleId != newWorkScheduleId ||
          newScheduleDate == null ||
          !_isSameDate(newScheduleDate, newDate)) {
        throw const BookingException(
          'The new schedule does not belong to this doctor or date.',
        );
      }
      if (newSlot.startTime == null || newSlot.endTime == null) {
        throw const BookingException('The new time slot is incomplete.');
      }
      if (newSlot.capacity == null || newSlot.capacity! < 1) {
        throw const BookingException('The new time slot has no valid capacity.');
      }
      if (newStartTime != newSlot.startTime || newEndTime != newSlot.endTime) {
        throw const BookingException(
          'The requested time does not match the new time slot.',
        );
      }

      final newBookedCount =
          (newSlot.bookedCount ?? 0) + appointment.peopleCount;
      if (newBookedCount > newSlot.capacity!) {
        throw const BookingException(
          'The new time slot does not have enough capacity.',
        );
      }
      final nextNewSlotStatus = newBookedCount >= newSlot.capacity!
          ? TimeSlotStatus.booked
          : TimeSlotStatus.available;

      // Release old slot
      if (oldSlotSnapshot.exists && oldSlotRef.id != newSlotRef.id) {
        final oldSlot = TimeSlotModel.fromFirestore(oldSlotSnapshot);
        final currentOldCount = oldSlot.bookedCount ?? 1;
        final newOldCount = (currentOldCount - appointment.peopleCount)
            .clamp(0, oldSlot.capacity ?? 9999)
            .toInt();
        final oldReservationCounts = Map<String, int>.from(
          oldSlot.reservationCounts,
        )..remove(appointment.id);
        transaction.update(oldSlotRef, {
          'bookedCount': newOldCount,
          'status': _slotStatusFor(newOldCount, oldSlot.capacity).firestoreValue,
          'appointmentId': appointment.id,
          'reservationCounts': oldReservationCounts,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // Update new slot
      if (oldSlotRef.id != newSlotRef.id) {
        final newReservationCounts = Map<String, int>.from(
          newSlot.reservationCounts,
        )..[appointment.id] = appointment.peopleCount;
        transaction.update(newSlotRef, {
          'bookedCount': newBookedCount,
          'status': nextNewSlotStatus.firestoreValue,
          'appointmentId': appointmentRef.id,
          'reservationCounts': newReservationCounts,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Just in case they reschedule to the EXACT same slot, though unlikely.
        transaction.update(newSlotRef, {
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // Update appointment
      transaction.update(appointmentRef, {
        'workScheduleId': newWorkScheduleId,
        'timeSlotId': newTimeSlotId,
        'appointmentDate': newScheduleDate,
        'startTime': newSlot.startTime,
        'endTime': newSlot.endTime,
        'status': AppointmentStatus
            .pending
            .firestoreValue, // reset status to pending when rescheduled
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return AppointmentModel(
        id: appointment.id,
        patientId: appointment.patientId,
        doctorId: appointment.doctorId,
        workScheduleId: newWorkScheduleId,
        timeSlotId: newTimeSlotId,
        specialtyId: appointment.specialtyId,
        appointmentDate: newScheduleDate,
        startTime: newSlot.startTime,
        endTime: newSlot.endTime,
        bookedAt: appointment.bookedAt,
        status: AppointmentStatus.pending,
        reason: appointment.reason,
        note: appointment.note,
        cancellationReason: appointment.cancellationReason,
        symptoms: appointment.symptoms,
        peopleCount: appointment.peopleCount,
        queueNumber: appointment.queueNumber,
        checkInTime: appointment.checkInTime,
        qrCode: appointment.qrCode,
        createdAt: appointment.createdAt,
        updatedAt: DateTime.now(),
      );
    });
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

  bool _isSameDate(DateTime source, DateTime target) =>
      source.year == target.year &&
      source.month == target.month &&
      source.day == target.day;

  TimeSlotStatus _slotStatusFor(int bookedCount, int? capacity) {
    if (capacity != null && capacity > 0 && bookedCount >= capacity) {
      return TimeSlotStatus.booked;
    }
    return TimeSlotStatus.available;
  }
}
