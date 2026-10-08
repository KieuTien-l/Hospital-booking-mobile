import 'package:flutter/material.dart';

import '../../../../core/themes/app_colors.dart';

class AppointmentCalendarLegend extends StatelessWidget {
  const AppointmentCalendarLegend({super.key});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: const BoxDecoration(
          color: AppColors.primarySoft,
          border: Border(
            left: BorderSide(color: AppColors.primaryDark, width: 4),
          ),
        ),
        child: const Text.rich(
          TextSpan(
            children: [
              TextSpan(text: 'Chọn ngày có '),
              TextSpan(
                text: 'màu xanh dương',
                style: TextStyle(
                  color: AppColors.primaryDark,
                  fontWeight: FontWeight.w700,
                ),
              ),
              TextSpan(text: ' để đặt khám.'),
            ],
          ),
        ),
      ),
      const SizedBox(height: 18),
      _item('Ngày có thể chọn khám', AppColors.primaryDark),
      _item(
        'Ngày không thể chọn khám',
        AppColors.divider,
        border: AppColors.disabled,
      ),
      _item('Ngày lễ, Tết', AppColors.surface, border: AppColors.warning),
    ],
  );

  Widget _item(String label, Color color, {Color? border}) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: border ?? color, width: 2),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ),
      ],
    ),
  );
}
