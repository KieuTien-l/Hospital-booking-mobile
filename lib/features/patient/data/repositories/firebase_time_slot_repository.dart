import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/models/time_slot_model.dart';
import '../../../../core/models/work_schedule_model.dart';
import '../../domain/repositories/time_slot_repository.dart';

/// Firestore-backed time-slot repository for the CA_KHAM collection.
class FirebaseTimeSlotRepository implements TimeSlotRepository {
  FirebaseTimeSlotRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _timeSlots =>
      _firestore.collection(TimeSlot.collectionName);
  CollectionReference<Map<String, dynamic>> get _workSchedules =>
      _firestore.collection(WorkSchedule.collectionName);

  @override
  Future<List<TimeSlot>> getTimeSlotsByWorkSchedule(
    String workScheduleId,
  ) async {
    final normalizedId = workScheduleId.trim();
    if (normalizedId.isEmpty) return const [];

    final snapshot = await _timeSlots
        .where('workScheduleId', isEqualTo: normalizedId)
        .get();
    return snapshot.docs.map(TimeSlot.fromFirestore).toList(growable: false);
  }

  @override
  Future<List<TimeSlot>> getAvailableTimeSlots(String workScheduleId) async {
    final slots = await getTimeSlotsByWorkSchedule(workScheduleId);
    return slots.where((slot) => slot.isAvailable).toList(growable: false);
  }

  @override
  Future<List<TimeSlot>> getTimeSlotsByDoctorAndDate({
    required String doctorId,
    required DateTime workDate,
  }) async {
    final normalizedDoctorId = doctorId.trim();
    if (normalizedDoctorId.isEmpty) return const [];

    final scheduleSnapshot = await _workSchedules
        .where('doctorId', isEqualTo: normalizedDoctorId)
        .get();
    final scheduleIds = scheduleSnapshot.docs
        .map(WorkSchedule.fromFirestore)
        .where((schedule) => schedule.status.toUpperCase() == 'ACTIVE')
        .where((schedule) => _isSameDate(schedule.workDate, workDate))
        .map((schedule) => schedule.id)
        .where((scheduleId) => scheduleId.isNotEmpty)
        .toList(growable: false);
    if (scheduleIds.isEmpty) return const [];

    final slotLists = await Future.wait(
      scheduleIds.map(getTimeSlotsByWorkSchedule),
    );
    return slotLists.expand((slots) => slots).toList(growable: false);
  }

  @override
  Future<List<TimeSlot>> getAvailableTimeSlotsByDoctorAndDate({
    required String doctorId,
    required DateTime workDate,
  }) async {
    final slots = await getTimeSlotsByDoctorAndDate(
      doctorId: doctorId,
      workDate: workDate,
    );
    return slots.where((slot) => slot.isAvailable).toList(growable: false);
  }

  bool _isSameDate(DateTime? source, DateTime target) {
    return source != null &&
        source.year == target.year &&
        source.month == target.month &&
        source.day == target.day;
  }
}
