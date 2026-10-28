class AppointmentTimeOption {
  const AppointmentTimeOption({
    required this.id,
    required this.workScheduleId,
    required this.label,
    this.startTime,
    this.endTime,
    this.startsAt,
    this.available = true,
  });
  final String id;
  final String workScheduleId;
  final String label;
  final String? startTime;
  final String? endTime;
  final DateTime? startsAt;
  final bool available;
}

/// Filters out a slot as soon as its start time has passed.  The exact
/// timestamp is preferred when it is available; old records only have the
/// HH:mm display value, which is still enough for a same-day comparison.
bool isUpcomingAppointmentTimeOption(
  DateTime date,
  AppointmentTimeOption slot, {
  DateTime? now,
}) {
  final current = now ?? DateTime.now();
  final selectedDay = DateTime(date.year, date.month, date.day);
  final currentDay = DateTime(current.year, current.month, current.day);
  if (selectedDay.isBefore(currentDay)) return false;
  if (selectedDay.isAfter(currentDay)) return true;

  final startsAt = slot.startsAt;
  if (startsAt != null) return startsAt.isAfter(current);

  final match = RegExp(r'^(\d{1,2}):(\d{2})$')
      .firstMatch(slot.startTime?.trim() ?? '');
  if (match == null) return false;
  final hour = int.tryParse(match.group(1)!);
  final minute = int.tryParse(match.group(2)!);
  if (hour == null || minute == null || hour > 23 || minute > 59) {
    return false;
  }
  return DateTime(
    date.year,
    date.month,
    date.day,
    hour,
    minute,
  ).isAfter(current);
}

List<AppointmentTimeOption> upcomingAppointmentTimeOptions(
  DateTime date,
  List<AppointmentTimeOption> slots, {
  DateTime? now,
}) => [
  for (final slot in slots)
    if (isUpcomingAppointmentTimeOption(date, slot, now: now)) slot,
];

class AppointmentDoctorOption {
  const AppointmentDoctorOption({
    required this.id,
    required this.name,
    required this.location,
    required this.session,
    required this.schedule,
    this.avatarUrl,
  });
  final String id;
  final String name;
  final String location;
  final String session;
  final String? avatarUrl;
  final Map<DateTime, List<AppointmentTimeOption>> schedule;
}

class AppointmentTimeSelection {
  const AppointmentTimeSelection({
    required this.doctor,
    required this.date,
    required this.slot,
  });
  final AppointmentDoctorOption doctor;
  final DateTime date;
  final AppointmentTimeOption slot;
}

String appointmentDateLabel(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
