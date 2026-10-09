import 'package:flutter/material.dart';

import '../../../../core/themes/app_colors.dart';
import '../models/appointment_time_ui_models.dart';

class AppointmentDateStrip extends StatelessWidget {
  const AppointmentDateStrip({
    super.key,
    required this.dates,
    required this.selected,
    required this.onSelected,
  });
  final List<DateTime> dates;
  final DateTime selected;
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        for (final date in dates)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Semantics(
              selected: DateUtils.isSameDay(date, selected),
              child: OutlinedButton(
                onPressed: () => onSelected(date),
                style: OutlinedButton.styleFrom(
                  backgroundColor: DateUtils.isSameDay(date, selected)
                      ? const Color(0xFFC7E2FF)
                      : AppColors.primarySoft,
                  foregroundColor: DateUtils.isSameDay(date, selected)
                      ? AppColors.primaryDark
                      : AppColors.textOnPrimary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: BorderSide.none,
                ),
                child: Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            appointmentDateLabel(date).substring(0, 5),
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: Colors.black,
                            ),
                          ),
                          Text(
                            '${date.year}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (DateUtils.isSameDay(date, selected))
                      const Positioned(
                        top: 0,
                        right: 0,
                        child: Icon(
                          Icons.check,
                          size: 14,
                          color: Color(0xFF2E7D4F),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
