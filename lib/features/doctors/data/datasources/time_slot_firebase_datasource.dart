import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/time_slot_model.dart';
import '../models/work_schedule_model.dart';

/// Firestore-backed time-slot repository for the CA_KHAM collection.
class TimeSlotFirebaseDatasource {
  TimeSlotFirebaseDatasource({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  static const _whereInLimit = 30;

  CollectionReference<Map<String, dynamic>> get _timeSlots =>
      _firestore.collection(TimeSlotModel.collectionName);
  CollectionReference<Map<String, dynamic>> get _workSchedules =>
      _firestore.collection(WorkScheduleModel.collectionName);

  Future<List<TimeSlot>> getTimeSlotsByWorkSchedule(
    String workScheduleId,
  ) async {
    final normalizedId = workScheduleId.trim();
    if (normalizedId.isEmpty) return const [];

    final snapshot = await _timeSlots
        .where('workScheduleId', isEqualTo: normalizedId)
        .get();
    return snapshot.docs
        .map(TimeSlotModel.fromFirestore)
        .toList(growable: false);
  }

  Future<List<TimeSlot>> getAvailableTimeSlots(String workScheduleId) async {
    final slots = await getTimeSlotsByWorkSchedule(workScheduleId);
    return slots.where((slot) => slot.isAvailable).toList(growable: false);
  }

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
        .map(WorkScheduleModel.fromFirestore)
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

  Future<List<TimeSlot>> getAvailableTimeSlotsByWorkScheduleIds({
    required List<String> workScheduleIds,
  }) async {
    final ids = _normalizedIds(workScheduleIds);
    if (ids.isEmpty) return const [];

    final snapshots = await Future.wait(
      _chunks(ids)
          .map((ids) => _timeSlots.where('workScheduleId', whereIn: ids).get()),
    );
    final slots = <String, TimeSlot>{
      for (final snapshot in snapshots)
        for (final document in snapshot.docs)
          document.id: TimeSlotModel.fromFirestore(document),
    };
    return slots.values
        .where((slot) => slot.isAvailable)
        .toList(growable: false);
  }

  bool _isSameDate(DateTime? source, DateTime target) {
    return source != null &&
        source.year == target.year &&
        source.month == target.month &&
        source.day == target.day;
  }

  Iterable<List<String>> _chunks(List<String> values) sync* {
    for (var start = 0; start < values.length; start += _whereInLimit) {
      final end = (start + _whereInLimit).clamp(0, values.length).toInt();
      yield values.sublist(start, end);
    }
  }

  List<String> _normalizedIds(Iterable<String> values) {
    final ids = <String>[];
    final seen = <String>{};
    for (final value in values) {
      final id = value.trim();
      if (id.isNotEmpty && seen.add(id)) ids.add(id);
    }
    return ids;
  }
}
