/// Presentation fixtures only; these dates do not represent hospital schedules.
abstract final class AppointmentCalendarDemoData {
  static Set<DateTime> availableDates(DateTime month) => {
    for (
      var day = 1;
      day <= DateTime(month.year, month.month + 1, 0).day;
      day++
    )
      if (!const {4, 11, 19, 26}.contains(day))
        DateTime(month.year, month.month, day),
  };

  /// An illustrative marker, not an official holiday calendar.
  static Set<DateTime> holidayDates(DateTime month) => {
    DateTime(month.year, month.month, 15),
  };
}
