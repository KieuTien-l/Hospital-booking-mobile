import '../../domain/entities/work_schedule.dart';
import '../../domain/repositories/work_schedule_repository.dart';
import '../datasources/work_schedule_firebase_datasource.dart';

class WorkScheduleRepositoryImpl implements WorkScheduleRepository {
  WorkScheduleRepositoryImpl(WorkScheduleFirebaseDatasource datasource)
    : _datasource = datasource;

  final WorkScheduleFirebaseDatasource _datasource;

  @override
  Future<List<WorkSchedule>> getWorkSchedules({
    required String doctorId,
    DateTime? workDate,
  }) => _datasource.getWorkSchedules(doctorId: doctorId, workDate: workDate);

  @override
  Future<List<WorkSchedule>> getWorkSchedulesForDoctorsAndDateRange({
    required List<String> doctorIds,
    required DateTime startDate,
    required DateTime endDate,
  }) => _datasource.getWorkSchedulesForDoctorsAndDateRange(
    doctorIds: doctorIds,
    startDate: startDate,
    endDate: endDate,
  );
}
