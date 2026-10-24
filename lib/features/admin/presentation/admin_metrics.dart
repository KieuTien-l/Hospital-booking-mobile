import '../../../core/utils/model_value_parser.dart';
import '../data/admin_repository.dart';

/// Calendar and aggregation rules shared by the admin dashboard and filters.
/// All periods use Vietnam calendar days; missing dates never become today.
DateTime? adminVietnamDate(Object? value) =>
    readDateTime(value)?.toUtc().add(const Duration(hours: 7));

DateTime adminDay(DateTime value) =>
    DateTime.utc(value.year, value.month, value.day);

bool adminSameDay(Object? value, DateTime day) {
  final date = adminVietnamDate(value);
  return date != null && adminDay(date) == adminDay(day);
}

bool adminInPeriod(Object? value, DateTime start, DateTime end) {
  final date = adminVietnamDate(value);
  if (date == null) return false;
  final day = adminDay(date);
  return !day.isBefore(adminDay(start)) && !day.isAfter(adminDay(end));
}

String adminStatus(Object? value) => readString(value).toUpperCase();

/// IDs remain separate even when two doctors share a display name.
Map<String, List<AdminRecord>> adminAppointmentsByDoctor(
  Iterable<AdminRecord> records,
) {
  final groups = <String, List<AdminRecord>>{};
  for (final record in records) {
    groups
        .putIfAbsent(readReferenceId(record.data['doctorId']), () => [])
        .add(record);
  }
  return groups;
}

bool adminCanBookSlot(
  AdminRecord slot,
  AdminRecord schedule, {
  required DateTime now,
}) {
  final data = slot.data;
  final date = adminVietnamDate(schedule.data['workDate']);
  final time = readString(data['startTime']);
  if (date == null ||
      !RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(time) ||
      data['status'] != 'AVAILABLE' ||
      schedule.data['status'] != 'ACTIVE' ||
      readReferenceId(data['workScheduleId']) != schedule.id ||
      readReferenceId(data['doctorId']).isEmpty ||
      readReferenceId(data['doctorId']) !=
          readReferenceId(schedule.data['doctorId']) ||
      data['capacity'] is! num ||
      data['bookedCount'] is! num ||
      readInt(data['capacity']) <= readInt(data['bookedCount'])) {
    return false;
  }
  final parts = time.split(':');
  final start = DateTime.utc(
    date.year,
    date.month,
    date.day,
    int.parse(parts[0]),
    int.parse(parts[1]),
  ).subtract(const Duration(hours: 7));
  return start.isAfter(now.toUtc());
}

/// Revenue requires a successful status, an actual paidAt and a valid amount.
/// createdAt is deliberately not used as a substitute for payment time.
double adminCollectedTotal(
  Iterable<AdminRecord> records,
  DateTime start,
  DateTime end,
) => records
    .where(
      (r) =>
          {'PAID', 'SUCCESS'}.contains(adminStatus(r.data['status'])) &&
          adminInPeriod(r.data['paidAt'], start, end),
    )
    .fold(0.0, (sum, r) {
      final amount = double.tryParse('${r.data['amount']}');
      return sum +
          (amount != null && amount.isFinite && amount >= 0 ? amount : 0);
    });
