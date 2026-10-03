import '../../../../core/models/time_slot_model.dart';

/// Reads examination time slots and their booking availability.
abstract class TimeSlotRepository {
  Future<List<TimeSlot>> getTimeSlotsByWorkSchedule(String workScheduleId);

  Future<List<TimeSlot>> getAvailableTimeSlots(String workScheduleId);

  /// Resolves the doctor's schedule for [workDate] before returning its slots.
  /// This includes booked slots so callers can show their status.
  Future<List<TimeSlot>> getTimeSlotsByDoctorAndDate({
    required String doctorId,
    required DateTime workDate,
  });

  /// Resolves the doctor's schedule for [workDate] and excludes booked slots.
  Future<List<TimeSlot>> getAvailableTimeSlotsByDoctorAndDate({
    required String doctorId,
    required DateTime workDate,
  });
}
