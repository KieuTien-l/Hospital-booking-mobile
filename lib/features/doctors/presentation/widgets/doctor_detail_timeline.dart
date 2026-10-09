import 'package:flutter/material.dart';

import '../../../../core/themes/app_colors.dart';
import '../models/doctor_detail_ui_model.dart';

class DoctorDetailTimeline extends StatelessWidget {
  const DoctorDetailTimeline({super.key, required this.items});
  final List<DoctorMilestoneUi> items;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (var i = 0; i < items.length; i++)
        Padding(
          padding: EdgeInsets.only(bottom: i == items.length - 1 ? 0 : 18),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.only(left: 12),
            decoration: const BoxDecoration(
              border: Border(
                left: BorderSide(color: AppColors.primaryLight, width: 3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  items[i].period,
                  style: const TextStyle(
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  items[i].title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (items[i].description?.isNotEmpty == true) ...[
                  const SizedBox(height: 4),
                  Text(
                    items[i].description!,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
    ],
  );
}
