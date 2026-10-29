import 'package:flutter/material.dart';

/// The patient booking journey exposes a single two-week window: from today
/// through the same weekday two weeks later. The range includes both
/// endpoints (15 calendar dates).
DateTime appointmentBookingWindowStart(DateTime now) {
  return DateUtils.dateOnly(now);
}

DateTime appointmentBookingWindowEnd(DateTime now) =>
    appointmentBookingWindowStart(now).add(const Duration(days: 14));

bool isWithinAppointmentBookingWindow(DateTime date, DateTime now) {
  final day = DateUtils.dateOnly(date);
  final start = appointmentBookingWindowStart(now);
  final end = appointmentBookingWindowEnd(now);
  return !day.isBefore(start) && !day.isAfter(end);
}

List<DateTime> appointmentBookingWindowDates(DateTime now) {
  final start = appointmentBookingWindowStart(now);
  return List<DateTime>.generate(
    15,
    (index) => start.add(Duration(days: index)),
    growable: false,
  );
}
