import 'package:flutter/material.dart';

import '../../../../core/themes/app_colors.dart';

class AppointmentCalendarDay extends StatelessWidget {
  const AppointmentCalendarDay({
    super.key,
    required this.date,
    required this.isAvailable,
    required this.isToday,
    required this.isHoliday,
    required this.isSelected,
    required this.onTap,
  });

  final DateTime date;
  final bool isAvailable;
  final bool isToday;
  final bool isHoliday;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = isAvailable ? Colors.white : AppColors.textSecondary;
    final border = isSelected
        ? AppColors.textOnPrimary
        : isHoliday
        ? AppColors.warning
        : isToday
        ? AppColors.textOnPrimary
        : Colors.transparent;
    return Semantics(
      label:
          '${date.day}/${date.month}/${date.year}'
          '${isToday ? ', Hôm nay' : ''}'
          '${isHoliday ? ', Ngày lễ, Tết' : ''}'
          ', ${isAvailable ? 'Có thể chọn khám' : 'Không thể chọn khám'}',
      button: true,
      enabled: isAvailable,
      selected: isSelected,
      child: Material(
        color: isAvailable ? AppColors.primaryDark : AppColors.divider,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: border, width: isSelected ? 3 : 2),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: isAvailable ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (isSelected)
                        Icon(Icons.check_rounded, size: 12, color: foreground),
                      Text(
                        '${date.day}',
                        style: TextStyle(
                          color: foreground,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isToday)
                  Text(
                    'Hôm nay',
                    maxLines: 1,
                    style: TextStyle(fontSize: 8, color: foreground),
                  ),
                if (isHoliday)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        color: AppColors.warning,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
