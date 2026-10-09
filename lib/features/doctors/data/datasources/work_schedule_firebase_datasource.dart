import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/work_schedule_model.dart';

/// Firestore-backed work schedule repository for LICH_LAM_VIEC.
class WorkScheduleFirebaseDatasource {
  WorkScheduleFirebaseDatasource({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  static const _whereInLimit = 30;

  CollectionReference<Map<String, dynamic>> get _workSchedules =>
      _firestore.collection(WorkScheduleModel.collectionName);

  Future<List<WorkSchedule>> getWorkSchedules({
    required String doctorId,
    DateTime? workDate,
  }) async {
    final normalizedDoctorId = doctorId.trim();
    if (normalizedDoctorId.isEmpty) return const [];

    final snapshot = await _workSchedules
        .where('doctorId', isEqualTo: normalizedDoctorId)
        .get();
    return snapshot.docs
        .map(WorkScheduleModel.fromFirestore)
        .where((schedule) => schedule.status.toUpperCase() == 'ACTIVE')
        .where(
          (schedule) =>
              workDate == null || _isSameDate(schedule.workDate, workDate),
        )
        .toList(growable: false);
  }

  Future<List<WorkSchedule>> getWorkSchedulesForDoctorsAndDateRange({
    required List<String> doctorIds,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final ids = _normalizedIds(doctorIds);
    if (ids.isEmpty) return const [];

    final start = _startOfDay(startDate);
    final endExclusive = _startOfDay(endDate).add(const Duration(days: 1));
    if (!endExclusive.isAfter(start)) return const [];

    final snapshots = await Future.wait(
      _chunks(ids).map(
        (ids) => _workSchedules
            .where('doctorId', whereIn: ids)
            .where('status', isEqualTo: 'ACTIVE')
            .where('workDate', isGreaterThanOrEqualTo: start)
            .where('workDate', isLessThan: endExclusive)
            .get(),
      ),
    );
    final schedules = <String, WorkSchedule>{
      for (final snapshot in snapshots)
        for (final document in snapshot.docs)
          document.id: WorkScheduleModel.fromFirestore(document),
    };
    return schedules.values.toList(growable: false);
  }

  bool _isSameDate(DateTime? source, DateTime target) {
    return source != null &&
        source.year == target.year &&
        source.month == target.month &&
        source.day == target.day;
  }

  DateTime _startOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day);

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
