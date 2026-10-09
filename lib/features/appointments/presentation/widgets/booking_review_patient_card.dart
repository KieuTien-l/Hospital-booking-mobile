import 'package:flutter/material.dart';

import '../../../../core/themes/app_colors.dart';
import '../models/appointment_confirmation_ui_model.dart';
import '../models/appointment_time_ui_models.dart';

class BookingReviewPatientCard extends StatelessWidget {
  const BookingReviewPatientCard({
    super.key,
    required this.information,
    required this.expanded,
    required this.onToggle,
  });
  final AppointmentConfirmationUiModel? information;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final patient = information?.patient;
    final gender = switch (patient?.gender?.toUpperCase()) {
      'MALE' || 'NAM' => 'Nam',
      'FEMALE' || 'NỮ' => 'Nữ',
      null || '' => 'Chưa có thông tin',
      _ => patient!.gender!,
    };
    final rows = <(String, String)>[
      (
        'Họ tên',
        patient?.fullName ??
            information?.patientName ??
            'Chưa có thông tin hồ sơ',
      ),
      ('Giới tính', gender),
      if (patient?.dateOfBirth != null)
        ('Ngày sinh', appointmentDateLabel(patient!.dateOfBirth!)),
      (
        'Điện thoại',
        patient?.phone.isNotEmpty == true
            ? patient!.phone
            : 'Chưa có thông tin',
      ),
      if (patient?.address?.isNotEmpty == true) ('Địa chỉ', patient!.address!),
      if (patient?.id.isNotEmpty == true) ('Mã hồ sơ', patient!.id),
    ];
    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          ListTile(
            key: const ValueKey('review-patient-toggle'),
            leading: const CircleAvatar(
              backgroundColor: AppColors.primarySoft,
              child: Icon(Icons.person_outline, color: AppColors.primaryDark),
            ),
            title: const Text(
              'Hồ sơ người bệnh',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            trailing: Icon(expanded ? Icons.expand_less : Icons.expand_more),
            onTap: onToggle,
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  const Divider(),
                  for (var i = 0; i < rows.length; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 2,
                            child: Text(
                              rows[i].$1,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 3,
                            child: Text(
                              rows[i].$2,
                              style: TextStyle(
                                color: i == 0
                                    ? AppColors.primaryDark
                                    : AppColors.textPrimary,
                                fontWeight: i == 0
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
