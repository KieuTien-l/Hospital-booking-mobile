import 'package:flutter/material.dart';

import '../../../../core/themes/app_colors.dart';

class BookingReviewActions extends StatelessWidget {
  const BookingReviewActions({
    super.key,
    required this.total,
    required this.onAddSpecialty,
    required this.onConfirm,
  });
  final String total;
  final VoidCallback onAddSpecialty;
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surface,
    elevation: 8,
    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 12,
              runSpacing: 4,
              children: [
                const Text(
                  'Tổng tiền khám',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                Text(
                  total,
                  style: const TextStyle(
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final add = OutlinedButton.icon(
                  onPressed: onAddSpecialty,
                  icon: const Icon(Icons.medical_services_outlined, size: 20),
                  label: const Text('Thêm chuyên khoa'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 52),
                    foregroundColor: AppColors.primaryDark,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                );
                final confirm = ElevatedButton(
                  key: const ValueKey('confirm-booking-review'),
                  onPressed: onConfirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryDark,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text(
                    'Xác nhận đặt khám',
                    textAlign: TextAlign.center,
                  ),
                );
                if (constraints.maxWidth < 440 ||
                    MediaQuery.textScalerOf(context).scale(16) > 20) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [add, const SizedBox(height: 8), confirm],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: add),
                    const SizedBox(width: 12),
                    Expanded(child: confirm),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    ),
  );
}
