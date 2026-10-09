import 'package:flutter/material.dart';

import '../../../../core/themes/app_colors.dart';
import '../models/appointment_time_ui_models.dart';
import 'appointment_date_strip.dart';
import 'appointment_time_slot_grid.dart';

class AppointmentDoctorCard extends StatelessWidget {
  const AppointmentDoctorCard({
    super.key,
    required this.doctor,
    required this.expanded,
    required this.date,
    required this.selectedSlotId,
    required this.onToggle,
    required this.onDateSelected,
    required this.onSlotSelected,
    required this.onInfo,
  });
  final AppointmentDoctorOption doctor;
  final bool expanded;
  final DateTime date;
  final String? selectedSlotId;
  final VoidCallback onToggle;
  final VoidCallback onInfo;
  final ValueChanged<DateTime> onDateSelected;
  final ValueChanged<AppointmentTimeOption> onSlotSelected;

  @override
  Widget build(BuildContext context) {
    final dates = doctor.schedule.keys.map(DateUtils.dateOnly).toSet().toList()
      ..sort();
    final slots =
        doctor.schedule.entries
            .where((entry) => DateUtils.isSameDay(entry.key, date))
            .firstOrNull
            ?.value ??
        const <AppointmentTimeOption>[];
    final avatar = Container(
      width: 88,
      height: 108,
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: doctor.avatarUrl == null
          ? const Icon(
              Icons.person_outline,
              size: 54,
              color: AppColors.textOnPrimary,
            )
          : Image.network(
              doctor.avatarUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const Icon(
                Icons.person_outline,
                size: 54,
                color: AppColors.textOnPrimary,
              ),
            ),
    );
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                avatar,
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        doctor.name,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: AppColors.textOnPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 6),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          doctor.location,
                          maxLines: 1,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextButton(
                        onPressed: onInfo,
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primaryDark,
                          backgroundColor: AppColors.primarySoft,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Thông tin bác sĩ ›'),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 48,
                  ),
                  key: ValueKey('expand-${doctor.id}'),
                  tooltip: expanded
                      ? 'Thu gọn ${doctor.name}'
                      : 'Mở rộng ${doctor.name}',
                  onPressed: onToggle,
                  icon: Icon(
                    expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                  ),
                ),
              ],
            ),
            if (expanded) ...[
              const SizedBox(height: 16),
              const _DashedDivider(),
              const SizedBox(height: 12),
              AppointmentDateStrip(
                dates: dates,
                selected: date,
                onSelected: onDateSelected,
              ),
              const SizedBox(height: 18),
              Text(
                '${appointmentDateLabel(date)} - ${doctor.session} (${date.weekday == 7 ? 'Chủ nhật' : 'Thứ ${date.weekday + 1}'})',
                style: TextStyle(
                  color: doctor.session.toLowerCase().contains('s\u00e1ng')
                      ? const Color(0xFF2E7D4F)
                      : doctor.session.toLowerCase().contains('chi\u1ec1u')
                      ? const Color(0xFFB77938)
                      : AppColors.textOnPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              AppointmentTimeSlotGrid(
                slots: slots,
                selectedId: selectedSlotId,
                onSelected: onSlotSelected,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DashedDivider extends StatelessWidget {
  const _DashedDivider();

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Row(
      children: List.generate(
        (constraints.maxWidth / 10).floor(),
        (_) => Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Container(height: 1.5, color: const Color(0xFFA8B8B2)),
          ),
        ),
      ),
    ),
  );
}
