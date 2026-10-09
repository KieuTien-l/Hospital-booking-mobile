import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/themes/app_colors.dart';
import 'appointment_calendar_day.dart';

class AppointmentCalendar extends StatelessWidget {
  const AppointmentCalendar({
    super.key,
    required this.month,
    required this.today,
    required this.availableDates,
    required this.holidayDates,
    required this.selectedDate,
    required this.onDateSelected,
    required this.onPreviousMonth,
    required this.onNextMonth,
  });

  final DateTime month;
  final DateTime today;
  final Set<DateTime> availableDates;
  final Set<DateTime> holidayDates;
  final DateTime? selectedDate;
  final ValueChanged<DateTime> onDateSelected;
  final VoidCallback? onPreviousMonth;
  final VoidCallback onNextMonth;

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(month.year, month.month);
    final offset = firstDay.weekday % 7;
    final days = DateTime(month.year, month.month + 1, 0).day;
    final cells = ((offset + days) / 7).ceil() * 7;
    return Column(
      children: [
        Row(
          children: [
            IconButton.filledTonal(
              tooltip: 'Tháng trước',
              onPressed: onPreviousMonth,
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            Expanded(
              child: Text(
                'Tháng ${month.month} - ${month.year}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textOnPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            IconButton.filled(
              tooltip: 'Tháng sau',
              style: IconButton.styleFrom(
                backgroundColor: AppColors.primaryDark,
                foregroundColor: Colors.white,
              ),
              onPressed: onNextMonth,
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            for (final weekday in const [
              'CN',
              'T2',
              'T3',
              'T4',
              'T5',
              'T6',
              'T7',
            ])
              Expanded(
                child: Text(
                  weekday,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = (constraints.maxWidth - 6 * 6) / 7;
            final scale = MediaQuery.textScalerOf(context).scale(1);
            final height = math.max(62.0, 52 * scale);
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: cells,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                crossAxisSpacing: 6,
                mainAxisSpacing: 6,
                childAspectRatio: width / height,
              ),
              itemBuilder: (context, index) {
                final day = index - offset + 1;
                if (day < 1 || day > days) return const SizedBox.shrink();
                final date = DateTime(month.year, month.month, day);
                final available =
                    !date.isBefore(DateUtils.dateOnly(today)) &&
                    availableDates.contains(date);
                return AppointmentCalendarDay(
                  key: ValueKey(date),
                  date: date,
                  isAvailable: available,
                  isToday: DateUtils.isSameDay(date, today),
                  isHoliday: holidayDates.contains(date),
                  isSelected: DateUtils.isSameDay(date, selectedDate),
                  onTap: available ? () => onDateSelected(date) : null,
                );
              },
            );
          },
        ),
      ],
    );
  }
}
