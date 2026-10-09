import '../../../../core/state/view_state.dart';
import '../../domain/entities/doctor.dart';
import '../../domain/entities/time_slot.dart';
import '../../domain/entities/work_schedule.dart';
import '../../domain/repositories/time_slot_repository.dart';
import '../../domain/repositories/work_schedule_repository.dart';

class ScheduleController extends ViewStateController {
  ScheduleController({
    required WorkScheduleRepository workScheduleRepository,
    required TimeSlotRepository timeSlotRepository,
  }) : _schedules = workScheduleRepository,
       _slots = timeSlotRepository;
  final WorkScheduleRepository _schedules;
  final TimeSlotRepository _slots;
  Doctor? _selectedDoctor;
  DateTime? _selectedDate;
  List<WorkSchedule> _workSchedules = const [];
  List<TimeSlot> _timeSlots = const [];
  Doctor? get selectedDoctor => _selectedDoctor;
  DateTime? get selectedDate => _selectedDate;
  List<WorkSchedule> get workSchedules => _workSchedules;
  List<TimeSlot> get timeSlots => _timeSlots;
  List<TimeSlot> get availableTimeSlots =>
      List.unmodifiable(_timeSlots.where((slot) => slot.isAvailable));
  Future<void> selectDoctor(Doctor? doctor) {
    _selectedDoctor = doctor;
    return loadSchedule();
  }

  Future<void> selectDate(DateTime? date) {
    _selectedDate = date == null
        ? null
        : DateTime(date.year, date.month, date.day);
    return loadSchedule();
  }

  Future<void> loadSchedule() async {
    _workSchedules = const [];
    _timeSlots = const [];
    final doctor = _selectedDoctor;
    final date = _selectedDate;
    final token = beginRequest();
    if (doctor == null) {
      setState(ViewState.initial);
      return;
    }
    try {
      final schedules = await _schedules.getWorkSchedules(
        doctorId: doctor.id,
        workDate: date,
      );
      if (!isCurrent(token)) return;
      final slots = date == null
          ? <TimeSlot>[]
          : await _slots.getTimeSlotsByDoctorAndDate(
              doctorId: doctor.id,
              workDate: date,
            );
      if (!isCurrent(token)) return;
      _workSchedules = List.unmodifiable(schedules);
      _timeSlots = List.unmodifiable(slots);
      setState(
        (date == null ? schedules.isEmpty : slots.isEmpty)
            ? ViewState.empty
            : ViewState.success,
      );
    } catch (error) {
      if (isCurrent(token)) setState(ViewState.error, error);
    }
  }

  Future<Map<String, Map<DateTime, List<TimeSlot>>>>
  loadWeeklySchedulesForDoctors({
    required List<Doctor> doctors,
    required DateTime startDate,
    required int days,
  }) async {
    if (days <= 0) return const {};

    final doctorIds = doctors
        .map((doctor) => doctor.id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (doctorIds.isEmpty) return {};

    final normalizedStart = DateTime(
      startDate.year,
      startDate.month,
      startDate.day,
    );
    final endDate = normalizedStart.add(Duration(days: days - 1));
    final schedules = await _schedules.getWorkSchedulesForDoctorsAndDateRange(
      doctorIds: doctorIds,
      startDate: normalizedStart,
      endDate: endDate,
    );

    final slots = await _slots.getAvailableTimeSlotsByWorkScheduleIds(
      workScheduleIds: schedules.map((schedule) => schedule.id).toList(),
    );

    final scheduleMap = {for (final s in schedules) s.id: s};

    final result = <String, Map<DateTime, List<TimeSlot>>>{};
    for (final doctor in doctors) {
      result[doctor.id] = {};
    }

    for (final slot in slots) {
      final schedule = scheduleMap[slot.workScheduleId];
      if (schedule != null && schedule.workDate != null) {
        final docMap = result[schedule.doctorId] ??= {};
        final date = DateTime(
          schedule.workDate!.year,
          schedule.workDate!.month,
          schedule.workDate!.day,
        );
        final dateSlots = docMap[date] ??= [];
        dateSlots.add(slot);
      }
    }

    for (final docMap in result.values) {
      for (final dateSlots in docMap.values) {
        dateSlots.sort(
          (a, b) => (a.startTime ?? '').compareTo(b.startTime ?? ''),
        );
      }
    }

    return result;
  }
}
