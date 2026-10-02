import '../../../../core/models/work_schedule_model.dart';

/// Reads a doctor's working schedules.
abstract class WorkScheduleRepository {
  /// When [workDate] is supplied, only schedules on that calendar date return.
  Future<List<WorkSchedule>> getWorkSchedules({
    required String doctorId,
    DateTime? workDate,
  });
}
