import 'package:flutter/material.dart';

import '../../../../core/themes/app_colors.dart';

class HealthRecordsDateFilter extends StatelessWidget {
  const HealthRecordsDateFilter({
    super.key,
    required this.fromDate,
    required this.toDate,
    required this.onFromTap,
    required this.onToTap,
  });

  final DateTime fromDate;
  final DateTime toDate;
  final VoidCallback onFromTap;
  final VoidCallback onToTap;

  static String format(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  Widget _field(
    BuildContext context,
    String label,
    DateTime date,
    VoidCallback onTap,
  ) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(16),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 8),
                Text(
                  format(date),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(
            Icons.calendar_month_outlined,
            color: AppColors.textOnPrimary,
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    clipBehavior: Clip.antiAlias,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final from = _field(context, 'Từ ngày', fromDate, onFromTap);
        final to = _field(context, 'Đến ngày', toDate, onToTap);
        if (constraints.maxWidth < 350 ||
            MediaQuery.textScalerOf(context).scale(1) > 1.3) {
          return Column(children: [from, const Divider(height: 1), to]);
        }
        return Row(
          children: [
            Expanded(child: from),
            const SizedBox(height: 40, child: VerticalDivider(width: 1)),
            Expanded(child: to),
          ],
        );
      },
    ),
  );
}
