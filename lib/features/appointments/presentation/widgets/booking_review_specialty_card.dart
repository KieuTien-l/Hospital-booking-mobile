import 'package:flutter/material.dart';

import '../../../../core/themes/app_colors.dart';
import '../models/appointment_confirmation_ui_model.dart';
import '../models/appointment_time_ui_models.dart';

class BookingReviewSpecialtyCard extends StatelessWidget {
  const BookingReviewSpecialtyCard({
    super.key,
    required this.item,
    required this.onRemove,
  });
  final AppointmentConfirmationResult item;
  final VoidCallback onRemove;

  Widget _group(Widget child) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.divider),
    ),
    child: child,
  );

  Widget _scheduleField(IconData icon, String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      Text(
        value,
        style: const TextStyle(fontWeight: FontWeight.w700, height: 1.4),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final information = item.information;
    final selection = information.selection;
    final roomAndTime = [
      selection.slot.label,
      if (selection.doctor.location.isNotEmpty) selection.doctor.location,
    ].join(', ');
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    information.specialtyName.toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Xóa chuyên khoa',
                  onPressed: onRemove,
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFFFF1F2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(
                    Icons.delete_outline,
                    color: AppColors.error,
                  ),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1),
            ),
            _group(
              LayoutBuilder(
                builder: (context, constraints) {
                  final date = _scheduleField(
                    Icons.calendar_today_outlined,
                    'Ngày khám',
                    appointmentDateLabel(selection.date),
                  );
                  final time = _scheduleField(
                    Icons.access_time,
                    'Phòng - Giờ khám',
                    roomAndTime,
                  );
                  if (constraints.maxWidth < 280 ||
                      MediaQuery.textScalerOf(context).scale(16) > 20) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [date, const Divider(height: 24), time],
                    );
                  }
                  return IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(flex: 2, child: date),
                        const VerticalDivider(width: 24),
                        Expanded(flex: 3, child: time),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.person_outline,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Bác sĩ: ${selection.doctor.name}',
                    style: const TextStyle(height: 1.4),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _group(
              Column(
                children: [
                  for (final row in <(String, String)>[
                    (
                      'Tiền khám',
                      information.fee == null || information.fee! < 0
                          ? 'Chưa có thông tin giá'
                          : appointmentFeeLabel(information.fee),
                    ),
                    ('BHYT', item.hasHealthInsurance ? 'Có' : 'Không'),
                    (
                      'Bảo hiểm tư nhân',
                      item.hasPrivateInsurance ? 'Có' : 'Không',
                    ),
                  ])
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              row.$1,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Text(
                              row.$2,
                              textAlign: TextAlign.end,
                              style: TextStyle(
                                color: row.$1 == 'Tiền khám'
                                    ? AppColors.primaryDark
                                    : AppColors.textPrimary,
                                fontWeight: row.$1 == 'Tiền khám'
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                                fontSize: row.$1 == 'Tiền khám' ? 20 : 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (information.isDemoFee)
                    const Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'Giá minh họa',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
