import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../doctors/data/models/doctor_model.dart';
import '../../../doctors/data/models/time_slot_model.dart';
import '../../../doctors/data/models/work_schedule_model.dart';
import '../../../specialties/data/models/specialty_model.dart';
import '../../domain/exceptions/admin_management_exception.dart';
import '../../domain/repositories/admin_management_repository.dart';

/// Firestore implementation of administrative writes.
///
/// Every write validates referenced records inside the transaction. This keeps
/// `CHUYEN_KHOA -> BAC_SI -> LICH_LAM_VIEC -> CA_KHAM` consistent even when
/// multiple administrators save data at the same time.
class AdminManagementRepositoryImpl implements AdminManagementRepository {
  AdminManagementRepositoryImpl({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _specialties =>
      _firestore.collection(SpecialtyModel.collectionName);
  CollectionReference<Map<String, dynamic>> get _doctors =>
      _firestore.collection(DoctorModel.collectionName);
  CollectionReference<Map<String, dynamic>> get _schedules =>
      _firestore.collection(WorkScheduleModel.collectionName);
  CollectionReference<Map<String, dynamic>> get _slots =>
      _firestore.collection(TimeSlotModel.collectionName);

  @override
  Future<Specialty> saveSpecialty(Specialty specialty) async {
    final saved = _normalizeSpecialty(specialty, _specialties.doc().id);
    _validateSpecialty(saved);
    if (!saved.isActive) {
      final doctors = await _doctors
          .where('specialtyId', isEqualTo: saved.id)
          .get();
      final hasActiveDoctor = doctors.docs
          .map(DoctorModel.fromFirestore)
          .any((doctor) => doctor.isActive);
      if (hasActiveDoctor) {
        throw const AdminManagementException(
          'Không thể ngừng hoạt động chuyên khoa đang có bác sĩ hoạt động.',
        );
      }
    }
    final document = _specialties.doc(saved.id);

    await _firestore.runTransaction((transaction) async {
      final existing = await transaction.get(document);
      transaction.set(document, {
        ...SpecialtyModel.fromEntity(saved).toFirestore(),
        if (!existing.exists) 'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
    return saved;
  }

  @override
  Future<Doctor> saveDoctor(Doctor doctor) async {
    final saved = _normalizeDoctor(doctor, _doctors.doc().id);
    _validateDoctor(saved);
    final document = _doctors.doc(saved.id);
    final specialtyDocument = _specialties.doc(saved.specialtyId);

    await _firestore.runTransaction((transaction) async {
      final specialtySnapshot = await transaction.get(specialtyDocument);
      if (!specialtySnapshot.exists) {
        throw const AdminManagementException('Chuyên khoa không tồn tại.');
      }
      final specialty = SpecialtyModel.fromFirestore(specialtySnapshot);
      if (saved.isActive && !specialty.isActive) {
        throw const AdminManagementException(
          'Không thể gán bác sĩ đang hoạt động vào chuyên khoa đã ngừng hoạt động.',
        );
      }

      final existing = await transaction.get(document);
      transaction.set(document, {
        ...DoctorModel.fromEntity(saved).toFirestore(),
        if (!existing.exists) 'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
    return saved;
  }

  @override
  Future<Doctor> transferDoctorToSpecialty({
    required String doctorId,
    required String targetSpecialtyId,
  }) async {
    final normalizedDoctorId = doctorId.trim();
    final normalizedSpecialtyId = targetSpecialtyId.trim();
    if (normalizedDoctorId.isEmpty || normalizedSpecialtyId.isEmpty) {
      throw const AdminManagementException(
        'Bác sĩ và chuyên khoa đích là bắt buộc.',
      );
    }

    final doctorDocument = _doctors.doc(normalizedDoctorId);
    final specialtyDocument = _specialties.doc(normalizedSpecialtyId);
    return _firestore.runTransaction((transaction) async {
      final doctorSnapshot = await transaction.get(doctorDocument);
      if (!doctorSnapshot.exists) {
        throw const AdminManagementException('Bác sĩ không tồn tại.');
      }
      final specialtySnapshot = await transaction.get(specialtyDocument);
      if (!specialtySnapshot.exists ||
          !SpecialtyModel.fromFirestore(specialtySnapshot).isActive) {
        throw const AdminManagementException(
          'Chuyên khoa đích không tồn tại hoặc đã ngừng hoạt động.',
        );
      }

      final current = DoctorModel.fromFirestore(doctorSnapshot);
      if (current.specialtyId == normalizedSpecialtyId) return current;
      final transferred = Doctor(
        id: current.id,
        userId: current.userId,
        fullName: current.fullName,
        email: current.email,
        phone: current.phone,
        specialtyId: normalizedSpecialtyId,
        yearsOfExperience: current.yearsOfExperience,
        consultationFee: current.consultationFee,
        isActive: current.isActive,
        status: current.status,
        specialtyName: SpecialtyModel.fromFirestore(specialtySnapshot).name,
        qualification: current.qualification,
        biography: current.biography,
        avatarUrl: current.avatarUrl,
        dateOfBirth: current.dateOfBirth,
        gender: current.gender,
        address: current.address,
        acceptingBookings: current.acceptingBookings,
        createdAt: current.createdAt,
        updatedAt: current.updatedAt,
      );
      transaction.update(
        doctorDocument,
        DoctorModel.fromEntity(transferred).toFirestore(),
      );
      return transferred;
    });
  }

  @override
  Future<WorkSchedule> saveWorkSchedule(WorkSchedule schedule) async {
    final saved = _normalizeSchedule(schedule, _schedules.doc().id);
    _validateSchedule(saved);
    await _validateScheduleDoesNotOverlap(saved);
    await _validateScheduleContainsExistingSlots(saved);
    final document = _schedules.doc(saved.id);
    final doctorDocument = _doctors.doc(saved.doctorId);

    await _firestore.runTransaction((transaction) async {
      final doctorSnapshot = await transaction.get(doctorDocument);
      if (!doctorSnapshot.exists ||
          !DoctorModel.fromFirestore(doctorSnapshot).isActive) {
        throw const AdminManagementException(
          'Bác sĩ không tồn tại hoặc đã ngừng hoạt động.',
        );
      }

      final existing = await transaction.get(document);
      if (existing.exists &&
          WorkScheduleModel.fromFirestore(existing).doctorId !=
              saved.doctorId) {
        throw const AdminManagementException(
          'Không thể đổi bác sĩ của lịch làm việc đã tồn tại.',
        );
      }
      transaction.set(document, {
        ...WorkScheduleModel.fromEntity(saved).toFirestore(),
        if (!existing.exists) 'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
    return saved;
  }

  @override
  Future<TimeSlot> saveTimeSlot(TimeSlot timeSlot) async {
    final input = _normalizeTimeSlot(timeSlot, _slots.doc().id);
    _validateTimeSlot(input);
    final document = _slots.doc(input.id);
    final scheduleDocument = _schedules.doc(input.workScheduleId);

    return _firestore.runTransaction((transaction) async {
      final scheduleSnapshot = await transaction.get(scheduleDocument);
      if (!scheduleSnapshot.exists) {
        throw const AdminManagementException('Lịch làm việc không tồn tại.');
      }
      final schedule = WorkScheduleModel.fromFirestore(scheduleSnapshot);
      if (schedule.status.toUpperCase() != 'ACTIVE') {
        throw const AdminManagementException(
          'Lịch làm việc không còn hoạt động.',
        );
      }
      if (input.doctorId.isNotEmpty && input.doctorId != schedule.doctorId) {
        throw const AdminManagementException(
          'Ca khám không thuộc bác sĩ của lịch làm việc đã chọn.',
        );
      }
      _validateSlotWithinSchedule(input, schedule);

      final existing = await transaction.get(document);
      final current = existing.exists
          ? TimeSlotModel.fromFirestore(existing)
          : null;
      if (current != null &&
          (current.workScheduleId != input.workScheduleId ||
              current.doctorId != schedule.doctorId)) {
        throw const AdminManagementException(
          'Không thể đổi lịch hoặc bác sĩ của ca khám đã tồn tại.',
        );
      }

      if (current != null &&
          (current.bookedCount ?? 0) > 0 &&
          (current.startTime != input.startTime ||
              current.endTime != input.endTime ||
              current.capacity != input.capacity)) {
        throw const AdminManagementException(
          'Không thể đổi giờ hoặc sức chứa của ca khám đã có lịch hẹn.',
        );
      }

      final bookedCount = current?.bookedCount ?? input.bookedCount ?? 0;
      final reservations =
          current?.reservationCounts ?? input.reservationCounts;
      final capacity = input.capacity ?? current?.capacity;
      if (capacity == null || capacity < bookedCount) {
        throw const AdminManagementException(
          'Sức chứa ca khám không được nhỏ hơn số lượt đã đặt.',
        );
      }
      if (_reservationCount(reservations) != bookedCount) {
        throw const AdminManagementException(
          'Số lượt đã đặt không khớp dữ liệu giữ chỗ.',
        );
      }
      final status =
          input.status == TimeSlotStatus.unavailable ||
              input.status == TimeSlotStatus.cancelled
          ? input.status
          : bookedCount >= capacity
          ? TimeSlotStatus.booked
          : input.status == TimeSlotStatus.booked
          ? TimeSlotStatus.available
          : input.status;
      final saved = TimeSlot(
        id: input.id,
        workScheduleId: input.workScheduleId,
        doctorId: schedule.doctorId,
        startTime: input.startTime,
        endTime: input.endTime,
        status: status,
        capacity: capacity,
        bookedCount: bookedCount,
        appointmentId: current?.appointmentId ?? input.appointmentId,
        reservationCounts: reservations,
      );
      transaction.set(document, {
        ...TimeSlotModel.fromEntity(saved).toFirestore(),
        if (!existing.exists) 'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return saved;
    });
  }

  Specialty _normalizeSpecialty(Specialty value, String generatedId) =>
      Specialty(
        id: _idOrGenerated(value.id, generatedId),
        name: value.name.trim(),
        description: value.description.trim(),
        isActive: value.isActive,
        status: value.isActive ? 'ACTIVE' : 'INACTIVE',
        imageUrl: _nullableText(value.imageUrl),
      );

  Doctor _normalizeDoctor(Doctor value, String generatedId) => Doctor(
    id: _idOrGenerated(value.id, generatedId),
    userId: value.userId.trim(),
    fullName: value.fullName.trim(),
    email: value.email.trim(),
    phone: value.phone.trim(),
    specialtyId: value.specialtyId.trim(),
    yearsOfExperience: value.yearsOfExperience,
    consultationFee: value.consultationFee,
    isActive: value.isActive,
    status: value.isActive ? 'ACTIVE' : 'INACTIVE',
    specialtyName: _nullableText(value.specialtyName),
    qualification: _nullableText(value.qualification),
    biography: _nullableText(value.biography),
    avatarUrl: _nullableText(value.avatarUrl),
    dateOfBirth: value.dateOfBirth,
    gender: _nullableText(value.gender),
    address: _nullableText(value.address),
    acceptingBookings: value.acceptingBookings,
    createdAt: value.createdAt,
    updatedAt: value.updatedAt,
  );

  WorkSchedule _normalizeSchedule(WorkSchedule value, String generatedId) =>
      WorkSchedule(
        id: _idOrGenerated(value.id, generatedId),
        doctorId: value.doctorId.trim(),
        workDate: value.workDate == null
            ? null
            : DateTime(
                value.workDate!.year,
                value.workDate!.month,
                value.workDate!.day,
              ),
        startTime: _nullableText(value.startTime),
        endTime: _nullableText(value.endTime),
        status: value.status.trim().isEmpty
            ? 'ACTIVE'
            : value.status.trim().toUpperCase(),
      );

  TimeSlot _normalizeTimeSlot(TimeSlot value, String generatedId) => TimeSlot(
    id: _idOrGenerated(value.id, generatedId),
    workScheduleId: value.workScheduleId.trim(),
    doctorId: value.doctorId.trim(),
    startTime: _nullableText(value.startTime),
    endTime: _nullableText(value.endTime),
    status: value.status == TimeSlotStatus.unknown
        ? TimeSlotStatus.available
        : value.status,
    capacity: value.capacity,
    bookedCount: value.bookedCount,
    appointmentId: _nullableText(value.appointmentId),
    reservationCounts: Map.unmodifiable(value.reservationCounts),
  );

  void _validateSpecialty(Specialty value) {
    if (value.name.isEmpty || value.name.length > 120) {
      throw const AdminManagementException('Tên chuyên khoa là bắt buộc.');
    }
  }

  void _validateDoctor(Doctor value) {
    if (value.userId.isEmpty ||
        value.fullName.isEmpty ||
        value.specialtyId.isEmpty) {
      throw const AdminManagementException(
        'Bác sĩ phải có tài khoản, họ tên và chuyên khoa.',
      );
    }
    if (value.yearsOfExperience < 0 ||
        !value.consultationFee.isFinite ||
        value.consultationFee < 0) {
      throw const AdminManagementException(
        'Kinh nghiệm và phí khám không được âm.',
      );
    }
  }

  void _validateSchedule(WorkSchedule value) {
    if (value.doctorId.isEmpty || value.workDate == null) {
      throw const AdminManagementException(
        'Lịch làm việc phải có bác sĩ và ngày làm việc.',
      );
    }
    _validateTimeRange(value.startTime, value.endTime, 'Lịch làm việc');
    if (value.workDate!.weekday == DateTime.sunday ||
        (value.workDate!.weekday == DateTime.saturday &&
            _minutes(value.endTime!) > 12 * 60)) {
      throw const AdminManagementException(
        'Thứ bảy chỉ khám buổi sáng, Chủ nhật nghỉ khám.',
      );
    }
  }

  void _validateTimeSlot(TimeSlot value) {
    if (value.workScheduleId.isEmpty) {
      throw const AdminManagementException(
        'Ca khám phải thuộc một lịch làm việc.',
      );
    }
    _validateTimeRange(value.startTime, value.endTime, 'Ca khám');
    if (value.capacity == null || value.capacity! <= 0) {
      throw const AdminManagementException('Sức chứa ca khám phải lớn hơn 0.');
    }
    if (value.bookedCount != null &&
        (value.bookedCount! < 0 || value.bookedCount! > value.capacity!)) {
      throw const AdminManagementException('Số lượt đã đặt không hợp lệ.');
    }
  }

  Future<void> _validateScheduleDoesNotOverlap(WorkSchedule schedule) async {
    if (schedule.status.toUpperCase() != 'ACTIVE') return;
    final sameDay = await _schedules
        .where('doctorId', isEqualTo: schedule.doctorId)
        .where('workDate', isEqualTo: schedule.workDate)
        .get();
    for (final document in sameDay.docs) {
      if (document.id == schedule.id) continue;
      final existing = WorkScheduleModel.fromFirestore(document);
      if (existing.status.toUpperCase() == 'ACTIVE' &&
          _rangesOverlap(
            schedule.startTime!,
            schedule.endTime!,
            existing.startTime,
            existing.endTime,
          )) {
        throw const AdminManagementException(
          'Bác sĩ đã có lịch làm việc trùng thời gian.',
        );
      }
    }
  }

  Future<void> _validateScheduleContainsExistingSlots(
    WorkSchedule schedule,
  ) async {
    final slots = await _slots
        .where('workScheduleId', isEqualTo: schedule.id)
        .get();
    for (final document in slots.docs) {
      final slot = TimeSlotModel.fromFirestore(document);
      if (slot.startTime == null ||
          slot.endTime == null ||
          _minutes(slot.startTime!) < _minutes(schedule.startTime!) ||
          _minutes(slot.endTime!) > _minutes(schedule.endTime!)) {
        throw const AdminManagementException(
          'Không thể đổi lịch khiến ca khám hiện có nằm ngoài giờ làm việc.',
        );
      }
    }
  }

  bool _rangesOverlap(
    String firstStart,
    String firstEnd,
    String? secondStart,
    String? secondEnd,
  ) {
    if (secondStart == null || secondEnd == null) return false;
    return _minutes(firstStart) < _minutes(secondEnd) &&
        _minutes(secondStart) < _minutes(firstEnd);
  }

  void _validateSlotWithinSchedule(TimeSlot slot, WorkSchedule schedule) {
    _validateTimeRange(schedule.startTime, schedule.endTime, 'Lịch làm việc');
    final slotStart = _minutes(slot.startTime!);
    final slotEnd = _minutes(slot.endTime!);
    if (slotStart < _minutes(schedule.startTime!) ||
        slotEnd > _minutes(schedule.endTime!)) {
      throw const AdminManagementException(
        'Khung giờ của ca khám phải nằm trong giờ làm việc của bác sĩ.',
      );
    }
  }

  void _validateTimeRange(String? start, String? end, String label) {
    if (start == null || end == null || _minutes(start) >= _minutes(end)) {
      throw AdminManagementException('Khoảng thời gian $label không hợp lệ.');
    }
  }

  int _minutes(String value) {
    final match = RegExp(r'^(?:[01]\d|2[0-3]):[0-5]\d$').firstMatch(value);
    if (match == null) {
      throw const AdminManagementException('Giờ phải có định dạng HH:mm.');
    }
    final parts = value.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  int _reservationCount(Map<String, int> values) =>
      values.values.fold(0, (total, reserved) => total + reserved);

  String _idOrGenerated(String value, String generatedId) =>
      value.trim().isEmpty ? generatedId : value.trim();

  String? _nullableText(String? value) {
    final normalized = value?.trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }
}
