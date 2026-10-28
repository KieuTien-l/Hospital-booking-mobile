import 'dart:async';

import '../../../../core/state/view_state.dart';
import '../../domain/entities/doctor_workspace.dart';
import '../../domain/repositories/doctor_workspace_repository.dart';

class DoctorWorkspaceController extends ViewStateController {
  DoctorWorkspaceController({
    required this.repository,
    required this.userId,
    this.refreshInterval = const Duration(seconds: 30),
  });
  final DoctorWorkspaceRepository repository;
  final String userId;
  final Duration? refreshInterval;
  DoctorDayData? data;
  DateTime? selectedDate;
  Timer? _timer;
  bool _pollingAllowed = true;

  bool matches(DateTime date) =>
      _same(selectedDate, DateTime(date.year, date.month, date.day));

  void pause() {
    _pollingAllowed = false;
    _timer?.cancel();
    _timer = null;
  }

  void resume() {
    _pollingAllowed = true;
    refresh();
  }

  static bool _same(DateTime? a, DateTime b) =>
      a != null && a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> load(DateTime date) async {
    final day = DateTime(date.year, date.month, date.day);
    if (isLoading && _same(selectedDate, day)) return;
    if (!_same(selectedDate, day)) data = null;
    selectedDate = day;
    final token = beginRequest();
    try {
      final result = await repository.loadDay(userId: userId, date: day);
      if (!isCurrent(token)) return;
      try {
        validate(result, userId: userId, date: day);
      } catch (_) {
        data = null;
        rethrow;
      }
      data = result;
      setState(result.schedules.isEmpty ? ViewState.empty : ViewState.success);
    } catch (error) {
      if (isCurrent(token)) {
        if (error is DoctorWorkspaceAccessException) data = null;
        setState(
          ViewState.error,
          error is StateError
              ? error.message
              : error is DoctorWorkspaceAccessException
              ? error.message
              : 'Không thể tải dữ liệu bác sĩ. Vui lòng thử lại.',
        );
      }
    }
    if (_pollingAllowed &&
        isCurrent(token) &&
        _timer == null &&
        !repository.isDemo &&
        refreshInterval != null) {
      _timer = Timer.periodic(refreshInterval!, (_) {
        if (!isLoading) refresh();
      });
    }
  }

  static void validate(
    DoctorDayData result, {
    required String userId,
    required DateTime date,
  }) {
    final day = date;
    final doctor = result.doctor;
    if (doctor.id.isEmpty ||
        doctor.userId != userId ||
        !doctor.isActive ||
        doctor.status.toUpperCase() != 'ACTIVE' ||
        !_same(result.date, day)) {
      throw StateError('Dữ liệu không thuộc bác sĩ hoặc ngày đang chọn.');
    }
    final schedules = {
      for (final schedule in result.schedules) schedule.id: schedule,
    };
    if (schedules.length != result.schedules.length ||
        result.schedules.any(
          (schedule) =>
              schedule.id.isEmpty ||
              schedule.doctorId != doctor.id ||
              !_same(schedule.workDate, day),
        )) {
      throw StateError('Lịch làm việc không hợp lệ.');
    }
    int minutes(String? value) {
      final parts = value?.split(':');
      if (parts == null || parts.length != 2) return -1;
      final hour = int.tryParse(parts[0]), minute = int.tryParse(parts[1]);
      if (hour == null ||
          minute == null ||
          hour < 0 ||
          hour > 23 ||
          minute < 0 ||
          minute > 59) {
        return -1;
      }
      return hour * 60 + minute;
    }

    if ((day.weekday == DateTime.sunday && result.schedules.isNotEmpty) ||
        (day.weekday == DateTime.saturday &&
            (result.schedules.any(
                  (schedule) =>
                      minutes(schedule.startTime) < 0 ||
                      minutes(schedule.startTime) >= 720 ||
                      minutes(schedule.endTime) > 720 ||
                      minutes(schedule.endTime) < 0,
                ) ||
                result.slots.any(
                  (slot) =>
                      minutes(slot.startTime) < 0 ||
                      minutes(slot.startTime) >= 720 ||
                      minutes(slot.endTime) > 720 ||
                      minutes(slot.endTime) < 0,
                )))) {
      throw StateError(
        'Lịch không hợp lệ: thứ bảy chỉ có buổi sáng, Chủ nhật nghỉ khám.',
      );
    }
    final slots = {for (final slot in result.slots) slot.id: slot};
    if (slots.length != result.slots.length ||
        result.slots.any(
          (slot) =>
              slot.id.isEmpty ||
              slot.doctorId != doctor.id ||
              !schedules.containsKey(slot.workScheduleId),
        )) {
      throw StateError('Ca khám không thuộc lịch của bác sĩ.');
    }
    final ids = <String>{};
    for (final booking in result.bookings) {
      final appointment = booking.appointment;
      if (!ids.add(appointment.id) ||
          appointment.id.isEmpty ||
          appointment.doctorId != doctor.id ||
          slots[appointment.timeSlotId]?.workScheduleId !=
              appointment.workScheduleId ||
          !schedules.containsKey(appointment.workScheduleId) ||
          !_same(appointment.appointmentDate, day) ||
          appointment.peopleCount < 1) {
        throw StateError(
          'Danh sách khám không thuộc ca hoặc bác sĩ đang chọn.',
        );
      }
    }
  }

  Future<void> refresh() async {
    final date = selectedDate;
    if (date != null) await load(date);
  }

  @override
  void dispose() {
    _timer?.cancel();
    data = null;
    super.dispose();
  }
}
