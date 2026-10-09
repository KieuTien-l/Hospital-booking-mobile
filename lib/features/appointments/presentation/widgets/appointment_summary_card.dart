import 'package:flutter/material.dart';

import '../../../../core/themes/app_colors.dart';
import '../models/appointment_confirmation_ui_model.dart';
import '../models/appointment_time_ui_models.dart';

class AppointmentSummaryCard extends StatelessWidget {
  const AppointmentSummaryCard({super.key, required this.information});
  final AppointmentConfirmationUiModel information;

  @override
  Widget build(BuildContext context) {
    final rows = <({IconData icon, String label, String value})>[
      if (information.patientName?.isNotEmpty == true)
        (
          icon: Icons.badge_outlined,
          label: 'Hồ sơ bệnh nhân',
          value: information.patientName!,
        ),
      (
        icon: Icons.medical_services_outlined,
        label: 'Chuyên khoa',
        value: information.specialtyName,
      ),
      (
        icon: Icons.calendar_today_outlined,
        label: 'Ngày khám',
        value: appointmentDateLabel(information.selection.date),
      ),
      (
        icon: Icons.access_time,
        label: 'Giờ khám',
        value: information.selection.slot.label,
      ),
      (
        icon: Icons.person_outline,
        label: 'Bác sĩ',
        value: information.selection.doctor.name,
      ),
      if (information.selection.doctor.location.isNotEmpty)
        (
          icon: Icons.location_on_outlined,
          label: 'Phòng khám',
          value: information.selection.doctor.location,
        ),
    ];
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Column(
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        rows[i].icon,
                        size: 22,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            rows[i].label,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            rows[i].value,
                            style: const TextStyle(
                              color: AppColors.textOnPrimary,
                              fontWeight: FontWeight.w700,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
