import '../../domain/entities/time_slot.dart';
import '../../domain/repositories/time_slot_repository.dart';
import '../datasources/time_slot_firebase_datasource.dart';

class TimeSlotRepositoryImpl implements TimeSlotRepository {
  TimeSlotRepositoryImpl(TimeSlotFirebaseDatasource datasource)
    : _datasource = datasource;

  final TimeSlotFirebaseDatasource _datasource;

  @override
  Future<List<TimeSlot>> getTimeSlotsByWorkSchedule(String workScheduleId) =>
      _datasource.getTimeSlotsByWorkSchedule(workScheduleId);

  @override
  Future<List<TimeSlot>> getAvailableTimeSlots(String workScheduleId) =>
      _datasource.getAvailableTimeSlots(workScheduleId);

  @override
  Future<List<TimeSlot>> getTimeSlotsByDoctorAndDate({
    required String doctorId,
    required DateTime workDate,
  }) => _datasource.getTimeSlotsByDoctorAndDate(
    doctorId: doctorId,
    workDate: workDate,
  );

  @override
  Future<List<TimeSlot>> getAvailableTimeSlotsByDoctorAndDate({
    required String doctorId,
    required DateTime workDate,
  }) => _datasource.getAvailableTimeSlotsByDoctorAndDate(
    doctorId: doctorId,
    workDate: workDate,
  );
}
