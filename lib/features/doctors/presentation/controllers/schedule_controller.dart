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
}
