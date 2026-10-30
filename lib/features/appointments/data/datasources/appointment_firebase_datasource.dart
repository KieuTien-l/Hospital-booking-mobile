import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../admin/data/admin_commands.dart';
import '../models/appointment_model.dart';
import '../../../doctors/data/models/doctor_model.dart';
import '../../../doctors/data/models/time_slot_model.dart';
import '../../../doctors/data/models/work_schedule_model.dart';
import '../../../profile/data/models/patient_model.dart';
import '../../domain/exceptions/booking_exception.dart';

/// Firestore-backed appointment repository for the LICH_HEN collection.
class AppointmentFirebaseDatasource {
  AppointmentFirebaseDatasource({
    FirebaseFirestore? firestore,
    AdminCommands? bookingCommands,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _bookingCommands =
           bookingCommands ??
           (const String.fromEnvironment('ADMIN_COMMAND_BASE_URL').isEmpty
               ? null
               : FirebaseAdminCommands());

  final FirebaseFirestore _firestore;
  // Production builds that configure the trusted Worker send the critical
  // multi-document reservation through it. Local/emulator builds retain the
  // direct transaction path used by the Firestore rules tests.
  final AdminCommands? _bookingCommands;

  /// Production reservations are server commands.  The direct transaction is
  /// intentionally retained only for local debug/emulator tests, where it
  /// verifies the paired Firestore Rules transaction.
  bool get _mayUseDirectFirestore => !kReleaseMode;

  BookingException get _workerRequired => const BookingException(
    'Dịch vụ đặt lịch chưa được cấu hình cho bản phát hành. Vui lòng liên hệ quản trị viên.',
  );

  CollectionReference<Map<String, dynamic>> get _appointments =>
      _firestore.collection(AppointmentModel.collectionName);
  CollectionReference<Map<String, dynamic>> get _timeSlots =>
      _firestore.collection(TimeSlotModel.collectionName);
  CollectionReference<Map<String, dynamic>> get _workSchedules =>
      _firestore.collection(WorkScheduleModel.collectionName);
  CollectionReference<Map<String, dynamic>> get _doctors =>
      _firestore.collection(DoctorModel.collectionName);
  CollectionReference<Map<String, dynamic>> get _notifications =>
      _firestore.collection('THONG_BAO');
  CollectionReference<Map<String, dynamic>> get _patients =>
      _firestore.collection(PatientModel.collectionName);

  Stream<List<Appointment>> watchAppointmentsByPatient(String patientId) {
    final normalizedId = patientId.trim();
    if (normalizedId.isEmpty) return Stream.value(const []);

    return _appointments
        .where('patientId', isEqualTo: normalizedId)
        .snapshots()
        .map((snapshot) {
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
        });
  }

  /// Administrators are authorized by Firestore rules to observe the full
  /// appointment collection. Keep ordering client-side to avoid requiring a
  /// compound index for the dashboard.
  Stream<List<Appointment>> watchAllAppointments() {
    return _appointments.snapshots().map(_sortAppointments);
  }

  /// Streams appointments assigned to the authenticated doctor's profile.
  /// Firestore rules authorize this query only for that exact doctor id.
  Stream<List<Appointment>> watchAppointmentsByDoctor(String doctorId) {
    final normalizedId = doctorId.trim();
    if (normalizedId.isEmpty) return Stream.value(const []);

    return _appointments
        .where('doctorId', isEqualTo: normalizedId)
        .snapshots()
        .map(_sortAppointments);
  }

  List<Appointment> _sortAppointments(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final appointments = snapshot.docs
        .map(AppointmentModel.fromFirestore)
        .toList();
    appointments.sort((a, b) {
      final aDate = a.appointmentDate ?? a.bookedAt ?? a.createdAt;
      final bDate = b.appointmentDate ?? b.bookedAt ?? b.createdAt;
      return (bDate ?? DateTime(0)).compareTo(aDate ?? DateTime(0));
    });
    return List.unmodifiable(appointments);
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

  Future<Appointment> createAppointment(Appointment appointment) {
    if (_bookingCommands != null) {
      return _createAppointmentThroughWorker(appointment);
    }
    if (!_mayUseDirectFirestore) return Future.error(_workerRequired);
    return _createAppointmentDirect(appointment);
  }

  Future<Appointment> _createAppointmentThroughWorker(
    Appointment appointment,
  ) async {
    _validateNewAppointment(appointment);
    try {
      final result = await _bookingCommands!.execute({
        'requestId': adminRequestId(),
        'operation': 'patientBook',
        'collection': AppointmentModel.collectionName,
        // The Worker protocol requires an auditable purpose. This is a
        // system label, not the patient's medical reason/symptoms.
        'reason': 'Bệnh nhân tự đặt lịch qua ứng dụng.',
        'values': {
          'patientId': appointment.patientId.trim(),
          'timeSlotId': appointment.timeSlotId.trim(),
          'peopleCount': appointment.peopleCount,
          if (appointment.reason?.trim().isNotEmpty ?? false)
            'reason': appointment.reason!.trim(),
        },
      });
      final appointmentId = result['id']?.toString().trim() ?? '';
      if (appointmentId.isEmpty) {
        throw const BookingException(
          'Máy chủ trả về mã lịch hẹn không hợp lệ.',
        );
      }
      final snapshot = await _appointments.doc(appointmentId).get();
      if (!snapshot.exists) {
        throw const BookingException(
          'Đã tạo lịch hẹn nhưng chưa tải được kết quả. Vui lòng mở Lịch hẹn để kiểm tra.',
        );
      }
      return AppointmentModel.fromFirestore(snapshot);
    } on AdminCommandException catch (error) {
      throw BookingException(error.message);
    }
  }

  Future<Appointment> _createAppointmentDirect(Appointment appointment) async {
    _validateNewAppointment(appointment);

    final appointmentDocument = _appointments.doc();
    final slotDocument = _timeSlots.doc(appointment.timeSlotId);
    final scheduleDocument = _workSchedules.doc(appointment.workScheduleId);
    final doctorDocument = _doctors.doc(appointment.doctorId);
    final patientDocument = _patients.doc(appointment.patientId);

    return _firestore.runTransaction((transaction) async {
      final slotSnapshot = await transaction.get(slotDocument);
      final scheduleSnapshot = await transaction.get(scheduleDocument);
      final doctorSnapshot = await transaction.get(doctorDocument);
      final patientSnapshot = await transaction.get(patientDocument);
      if (!slotSnapshot.exists ||
          !scheduleSnapshot.exists ||
          !doctorSnapshot.exists ||
          !patientSnapshot.exists) {
        throw const BookingException(
          'The selected schedule, time slot, or patient profile no longer exists.',
        );
      }

      final slot = TimeSlotModel.fromFirestore(slotSnapshot);
      final schedule = WorkScheduleModel.fromFirestore(scheduleSnapshot);
      final doctor = DoctorModel.fromFirestore(doctorSnapshot);
      final patient = PatientModel.fromFirestore(patientSnapshot);
      if (kDebugMode) {
        debugPrint(
          '[booking preflight] patient=${patient.id} authUser=${patient.authUserId} '
          'requestPatient=${appointment.patientId} slot=${slot.id} '
          'slotSchedule=${slot.workScheduleId} slotDoctor=${slot.doctorId} '
          'slotStatus=${slot.status.firestoreValue} booked=${slot.bookedCount} '
          'capacity=${slot.capacity} scheduleDoctor=${schedule.doctorId} '
          'scheduleStatus=${schedule.status} doctor=${doctor.id} '
          'doctorSpecialty=${doctor.specialtyId} doctorStatus=${doctor.status} '
          'accepting=${doctorSnapshot.data()?['acceptingBookings']}',
        );
      }
      if (!slot.isAvailable) {
        throw const BookingException('This time slot is no longer available.');
      }
      if (!doctor.isActive ||
          doctorSnapshot.data()?['acceptingBookings'] == false ||
          schedule.status != 'ACTIVE' ||
          !patient.isActive) {
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
      if (!_isFutureSlot(slot, schedule.workDate!, slot.startTime!)) {
        throw const BookingException(
          'Không thể đặt lịch vào khung giờ đã qua.',
        );
      }
      if ((appointment.startTime != null &&
              appointment.startTime != slot.startTime) ||
          (appointment.endTime != null &&
              appointment.endTime != slot.endTime)) {
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
        patientCode: appointment.patientCode?.trim().isNotEmpty == true
            ? appointment.patientCode
            : (patient.patientCode.trim().isEmpty ? null : patient.patientCode),
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
  ) {
    if (_bookingCommands != null) {
      return _cancelAppointmentThroughWorker(appointmentId, cancellationReason);
    }
    if (!_mayUseDirectFirestore) return Future.error(_workerRequired);
    return _cancelAppointmentDirect(appointmentId, cancellationReason);
  }

  Future<Appointment> _cancelAppointmentThroughWorker(
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
    return _runPatientWorkerCommand(
      operation: 'patientCancel',
      appointmentId: normalizedId,
      values: {'cancellationReason': cancellationReason.trim()},
      reason: 'Bệnh nhân tự hủy lịch qua ứng dụng.',
    );
  }

  Future<Appointment> _cancelAppointmentDirect(
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
    final notificationRef = _notifications.doc();

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

      if (!slotSnapshot.exists) {
        throw const BookingException(
          'Ca khám gốc không còn tồn tại; cần quản trị viên xử lý dữ liệu.',
        );
      }
      final slot = TimeSlotModel.fromFirestore(slotSnapshot);
      final appointmentDate = appointment.appointmentDate;
      if (appointmentDate == null ||
          !_isFutureSlot(slot, appointmentDate, appointment.startTime ?? '')) {
        throw const BookingException(
          'Không thể hủy lịch khi ca khám đã bắt đầu.',
        );
      }
      if (slot.reservationCounts[appointment.id] != appointment.peopleCount ||
          (slot.bookedCount ?? -1) < appointment.peopleCount) {
        throw const BookingException(
          'Dữ liệu giữ chỗ không nhất quán; không thể tự hủy lịch.',
        );
      }
      final newCount = (slot.bookedCount! - appointment.peopleCount);
      final reservationCounts = Map<String, int>.from(slot.reservationCounts)
        ..remove(appointment.id);
      transaction.update(slotRef, {
        'bookedCount': newCount,
        // A doctor/admin may have intentionally locked the slot after it was
        // booked. Cancelling an appointment releases capacity but must not
        // silently reopen that locked slot.
        'status':
            (slot.status == TimeSlotStatus.unavailable ||
                slot.status == TimeSlotStatus.cancelled)
            ? slot.status.firestoreValue
            : _slotStatusFor(newCount, slot.capacity).firestoreValue,
        'appointmentId': appointment.id,
        'reservationCounts': reservationCounts,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      transaction.set(notificationRef, {
        'patientId': appointment.patientId,
        'appointmentId': appointment.id,
        'title': 'Hủy lịch thành công',
        'content': _cancellationNotificationContent(appointment),
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      return AppointmentModel(
        id: appointment.id,
        patientId: appointment.patientId,
        patientCode: appointment.patientCode,
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

  String _cancellationNotificationContent(Appointment appointment) {
    final date = appointment.appointmentDate;
    final dateLabel = date == null
        ? ''
        : ' ngày ${date.day.toString().padLeft(2, '0')}/'
              '${date.month.toString().padLeft(2, '0')}/${date.year}';
    final timeLabel = appointment.startTime?.trim() ?? '';
    final scheduleLabel = timeLabel.isEmpty
        ? dateLabel
        : ' lúc $timeLabel$dateLabel';
    return 'Lịch hẹn$scheduleLabel đã được hủy. Khung giờ đã được giải phóng.';
  }

  Future<Appointment> rescheduleAppointment({
    required String appointmentId,
    required String newWorkScheduleId,
    required String newTimeSlotId,
    required DateTime newDate,
    required String newStartTime,
    required String newEndTime,
  }) {
    if (_bookingCommands != null) {
      return _rescheduleAppointmentThroughWorker(
        appointmentId: appointmentId,
        newWorkScheduleId: newWorkScheduleId,
        newTimeSlotId: newTimeSlotId,
        newDate: newDate,
        newStartTime: newStartTime,
        newEndTime: newEndTime,
      );
    }
    if (!_mayUseDirectFirestore) return Future.error(_workerRequired);
    return _rescheduleAppointmentDirect(
      appointmentId: appointmentId,
      newWorkScheduleId: newWorkScheduleId,
      newTimeSlotId: newTimeSlotId,
      newDate: newDate,
      newStartTime: newStartTime,
      newEndTime: newEndTime,
    );
  }

  Future<Appointment> _rescheduleAppointmentThroughWorker({
    required String appointmentId,
    required String newWorkScheduleId,
    required String newTimeSlotId,
    required DateTime newDate,
    required String newStartTime,
    required String newEndTime,
  }) async {
    final normalizedId = appointmentId.trim();
    if (normalizedId.isEmpty || newTimeSlotId.trim().isEmpty) {
      throw const BookingException(
        'An appointment and a new time slot are required.',
      );
    }
    // The Worker derives the schedule/date/time from the canonical slot. The
    // values remain inputs here only to preserve the repository interface.
    return _runPatientWorkerCommand(
      operation: 'patientReschedule',
      appointmentId: normalizedId,
      values: {'timeSlotId': newTimeSlotId.trim()},
      reason: 'Bệnh nhân tự đổi lịch qua ứng dụng.',
    );
  }

  Future<Appointment> _runPatientWorkerCommand({
    required String operation,
    required String appointmentId,
    required Map<String, dynamic> values,
    required String reason,
  }) async {
    try {
      final result = await _bookingCommands!.execute({
        'requestId': adminRequestId(),
        'operation': operation,
        'collection': AppointmentModel.collectionName,
        'id': appointmentId,
        'reason': reason,
        'values': values,
      });
      final resultId = result['id']?.toString().trim() ?? '';
      if (resultId != appointmentId) {
        throw const BookingException(
          'Máy chủ trả về mã lịch hẹn không hợp lệ.',
        );
      }
      final snapshot = await _appointments.doc(appointmentId).get();
      if (!snapshot.exists) {
        throw const BookingException('Không tải được lịch hẹn vừa cập nhật.');
      }
      return AppointmentModel.fromFirestore(snapshot);
    } on AdminCommandException catch (error) {
      throw BookingException(error.message);
    }
  }

  Future<Appointment> _rescheduleAppointmentDirect({
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
      if (!_isFutureSlot(newSlot, newScheduleDate, newSlot.startTime!)) {
        throw const BookingException('Không thể đổi sang khung giờ đã qua.');
      }
      if (newSlot.capacity == null || newSlot.capacity! < 1) {
        throw const BookingException(
          'The new time slot has no valid capacity.',
        );
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
      if (!oldSlotSnapshot.exists) {
        throw const BookingException(
          'Ca khám cũ không còn tồn tại; cần quản trị viên xử lý dữ liệu.',
        );
      }
      final oldSlot = TimeSlotModel.fromFirestore(oldSlotSnapshot);
      final oldDate = appointment.appointmentDate;
      if (oldDate == null ||
          !_isFutureSlot(oldSlot, oldDate, appointment.startTime ?? '')) {
        throw const BookingException(
          'Không thể đổi lịch khi ca khám cũ đã bắt đầu.',
        );
      }
      if (oldSlotRef.id != newSlotRef.id) {
        if (oldSlot.reservationCounts[appointment.id] !=
                appointment.peopleCount ||
            (oldSlot.bookedCount ?? -1) < appointment.peopleCount) {
          throw const BookingException('Dữ liệu giữ chỗ cũ không nhất quán.');
        }
        final newOldCount = oldSlot.bookedCount! - appointment.peopleCount;
        final oldReservationCounts = Map<String, int>.from(
          oldSlot.reservationCounts,
        )..remove(appointment.id);
        transaction.update(oldSlotRef, {
          'bookedCount': newOldCount,
          'status':
              (oldSlot.status == TimeSlotStatus.unavailable ||
                  oldSlot.status == TimeSlotStatus.cancelled)
              ? oldSlot.status.firestoreValue
              : _slotStatusFor(newOldCount, oldSlot.capacity).firestoreValue,
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
        'queueNumber': FieldValue.delete(),
        'checkInTime': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return AppointmentModel(
        id: appointment.id,
        patientId: appointment.patientId,
        patientCode: appointment.patientCode,
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
        queueNumber: null,
        checkInTime: null,
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

  bool _isFutureSchedule(DateTime date, String time) {
    final pieces = time.split(':');
    if (pieces.length != 2) return false;
    final hour = int.tryParse(pieces[0]);
    final minute = int.tryParse(pieces[1]);
    if (hour == null || minute == null) return false;
    return DateTime(
      date.year,
      date.month,
      date.day,
      hour,
      minute,
    ).isAfter(DateTime.now());
  }

  bool _isFutureSlot(TimeSlot slot, DateTime date, String time) =>
      slot.startsAt?.isAfter(DateTime.now()) ?? _isFutureSchedule(date, time);

  TimeSlotStatus _slotStatusFor(int bookedCount, int? capacity) {
    if (capacity != null && capacity > 0 && bookedCount >= capacity) {
      return TimeSlotStatus.booked;
    }
    return TimeSlotStatus.available;
  }
}
