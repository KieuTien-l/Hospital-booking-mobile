import 'package:flutter/material.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../profile/presentation/widgets/health_records_date_filter.dart';
import '../models/appointment_history_ui_model.dart';

class AppointmentHistoryCard extends StatelessWidget {
  const AppointmentHistoryCard({
    super.key,
    required this.item,
    required this.onTap,
  });
  final AppointmentHistoryUiModel item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final appointment = item.appointment;
    final rows = [
      ('Bệnh nhân', item.patientName),
      ('Bác sĩ', item.doctorName),
      (
        'Ngày khám',
        appointment.appointmentDate == null
            ? 'Chưa cập nhật'
            : HealthRecordsDateFilter.format(appointment.appointmentDate!),
      ),
      (
        'Khung giờ',
        '${appointment.startTime ?? '--:--'} – ${appointment.endTime ?? '--:--'}',
      ),
      if (item.room?.isNotEmpty ?? false) ('Phòng khám', item.room!),
    ];
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                appointment.id,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Text(
                item.specialtyName,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textOnPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              for (final row in rows)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '${row.$1}: ${row.$2}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              if (item.tab != null)
                Chip(
                  label: Text(item.tab!.label),
                  backgroundColor: AppColors.primarySoft,
                  labelStyle: const TextStyle(color: AppColors.textOnPrimary),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
