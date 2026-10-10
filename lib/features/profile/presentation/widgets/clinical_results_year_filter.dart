import 'package:flutter/material.dart';

import '../../../../core/themes/app_colors.dart';

class ClinicalResultsYearFilter extends StatelessWidget {
  const ClinicalResultsYearFilter({
    super.key,
    required this.year,
    required this.maxYear,
    required this.onChanged,
  });

  final int year;
  final int maxYear;
  final ValueChanged<int> onChanged;
  static const minYear = 1900;

  Future<void> _pick(BuildContext context) async {
    final picked = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Chọn năm'),
        content: SizedBox(
          width: 300,
          height: 300,
          child: YearPicker(
            firstDate: DateTime(minYear),
            lastDate: DateTime(maxYear, 12, 31),
            selectedDate: DateTime(year),
            onChanged: (date) => Navigator.of(context).pop(date.year),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Hủy'),
          ),
        ],
      ),
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surface,
    shape: const StadiumBorder(side: BorderSide(color: AppColors.border)),
    clipBehavior: Clip.antiAlias,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Năm trước',
          onPressed: year > minYear ? () => onChanged(year - 1) : null,
          icon: const Icon(Icons.chevron_left),
          color: AppColors.textOnPrimary,
        ),
        TextButton.icon(
          onPressed: () => _pick(context),
          icon: const Icon(Icons.calendar_month_outlined, size: 20),
          label: Text('$year'),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.textOnPrimary,
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Năm sau',
          onPressed: year < maxYear ? () => onChanged(year + 1) : null,
          icon: const Icon(Icons.chevron_right),
          color: AppColors.textOnPrimary,
        ),
      ],
    ),
  );
}
