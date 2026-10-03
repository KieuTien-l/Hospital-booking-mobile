import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/models/work_schedule_model.dart';
import '../../domain/repositories/work_schedule_repository.dart';

/// Firestore-backed work schedule repository for LICH_LAM_VIEC.
class FirebaseWorkScheduleRepository implements WorkScheduleRepository {
  FirebaseWorkScheduleRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _workSchedules =>
      _firestore.collection(WorkSchedule.collectionName);

  @override
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
        .map(WorkSchedule.fromFirestore)
        .where((schedule) => schedule.status.toUpperCase() == 'ACTIVE')
        .where(
          (schedule) =>
              workDate == null || _isSameDate(schedule.workDate, workDate),
        )
        .toList(growable: false);
  }

  bool _isSameDate(DateTime? source, DateTime target) {
    return source != null &&
        source.year == target.year &&
        source.month == target.month &&
        source.day == target.day;
  }
}
