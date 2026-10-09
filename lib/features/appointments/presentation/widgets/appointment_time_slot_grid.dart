import 'package:flutter/material.dart';

import '../../../../core/themes/app_colors.dart';
import '../models/appointment_time_ui_models.dart';

class AppointmentTimeSlotGrid extends StatelessWidget {
  const AppointmentTimeSlotGrid({
    super.key,
    required this.slots,
    required this.selectedId,
    required this.onSelected,
  });
  final List<AppointmentTimeOption> slots;
  final String? selectedId;
  final ValueChanged<AppointmentTimeOption> onSelected;

  @override
  Widget build(BuildContext context) {
    if (slots.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Text(
          'Không có khung giờ khám trong ngày này.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) => Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final slot in slots)
            SizedBox(
              width: (constraints.maxWidth - 10) / 2,
              child: Semantics(
                selected: selectedId == slot.id,
                child: OutlinedButton(
                  key: ValueKey('slot-${slot.id}'),
                  onPressed: slot.available ? () => onSelected(slot) : null,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 64),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 14,
                    ),
                    backgroundColor: selectedId == slot.id
                        ? AppColors.primaryDark
                        : AppColors.primarySoft,
                    foregroundColor: selectedId == slot.id
                        ? Colors.white
                        : AppColors.primaryDark,
                    disabledBackgroundColor: AppColors.divider,
                    disabledForegroundColor: AppColors.textSecondary,
                    side: BorderSide(
                      color: selectedId == slot.id
                          ? AppColors.primaryDark
                          : Colors.transparent,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        slot.label,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      if (!slot.available)
                        const Text('Hết số', style: TextStyle(fontSize: 12)),
                      if (selectedId == slot.id)
                        const Text('Đã chọn ✓', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
