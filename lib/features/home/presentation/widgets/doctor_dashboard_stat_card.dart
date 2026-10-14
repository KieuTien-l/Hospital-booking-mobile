import 'package:flutter/material.dart';

import '../../../../core/themes/app_colors.dart';

class DoctorDashboardStatCard extends StatelessWidget {
  const DoctorDashboardStatCard({
    super.key,
    required this.label,
    required this.icon,
    this.value,
    this.isLoading = false,
    this.hasError = false,
  });
  final String label;
  final IconData icon;

  /// Only supply a value whose source and definition have been verified.
  final int? value;
  final bool isLoading;
  final bool hasError;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Padding(
              padding: const EdgeInsets.all(9),
              child: Icon(icon, size: 22, color: AppColors.textOnPrimary),
            ),
          ),
          const SizedBox(height: 12),
          Semantics(
            label: value == null && !isLoading && !hasError
                ? '$label: Chưa có dữ liệu'
                : null,
            child: Text(
              isLoading
                  ? '…'
                  : hasError
                  ? '!'
                  : value?.toString() ?? '—',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppColors.textOnPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelMedium
                ?.copyWith(color: AppColors.textPrimary),
          ),
        ],
      ),
    ),
  );
}
