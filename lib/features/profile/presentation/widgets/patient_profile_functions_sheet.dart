import 'package:flutter/material.dart';

import '../../../../core/themes/app_colors.dart';
import '../../domain/entities/patient.dart';
import '../pages/patient_health_records_page.dart';
import '../pages/patient_clinical_results_page.dart';
import '../pages/patient_imaging_page.dart';
import '../pages/patient_booking_history_page.dart';
import '../pages/patient_profile_information_page.dart';

class PatientProfileFunctionsSheet extends StatelessWidget {
  const PatientProfileFunctionsSheet({super.key, required this.patient});

  final Patient patient;

  static const _functions = [
    (
      Icons.monitor_heart_rounded,
      'HỒ SƠ SỨC KHỎE',
      'Xem lịch sử khám (đơn thuốc, phiếu chỉ định...)',
    ),
    (
      Icons.description_rounded,
      'KẾT QUẢ CẬN LÂM SÀNG',
      'Xem kết quả xét nghiệm, siêu âm...',
    ),
    (
      Icons.collections_rounded,
      'HÌNH ẢNH CHỤP (PACS)',
      'Xem hình ảnh X Quang, MRI, CT Scan...',
    ),
    (Icons.assignment_rounded, 'PHIẾU ĐĂNG KÝ KHÁM', 'Lịch sử đặt khám'),
    (
      Icons.manage_accounts_rounded,
      'THÔNG TIN HỒ SƠ',
      'Xem hoặc gỡ liên kết hồ sơ',
    ),
  ];

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const SizedBox(width: 48),
              Expanded(
                child: Text(
                  'Chọn chức năng',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                tooltip: 'Đóng',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, color: AppColors.textSecondary),
              ),
            ],
          ),
          Text(
            '${patient.fullName.toUpperCase()} • ${patient.id}',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          for (final function in _functions)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Material(
                color: AppColors.background,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: AppColors.divider),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () {
                    if (function.$2 == 'THÔNG TIN HỒ SƠ') {
                      Navigator.of(context).push<void>(
                        MaterialPageRoute(
                          builder: (_) =>
                              PatientProfileInformationPage(patient: patient),
                        ),
                      );
                      return;
                    }
                    if (function.$2 == 'PHIẾU ĐĂNG KÝ KHÁM') {
                      Navigator.of(context).push<void>(
                        MaterialPageRoute(
                          builder: (_) =>
                              PatientBookingHistoryPage(patient: patient),
                        ),
                      );
                      return;
                    }
                    if (function.$2 == 'HÌNH ẢNH CHỤP (PACS)') {
                      Navigator.of(context).push<void>(
                        MaterialPageRoute(
                          builder: (_) => PatientImagingPage(patient: patient),
                        ),
                      );
                      return;
                    }
                    if (function.$2 == 'KẾT QUẢ CẬN LÂM SÀNG') {
                      Navigator.of(context).push<void>(
                        MaterialPageRoute(
                          builder: (_) =>
                              PatientClinicalResultsPage(patient: patient),
                        ),
                      );
                      return;
                    }
                    if (function.$2 == 'HỒ SƠ SỨC KHỎE') {
                      Navigator.of(context).push<void>(
                        MaterialPageRoute(
                          builder: (_) =>
                              PatientHealthRecordsPage(patient: patient),
                        ),
                      );
                      return;
                    }
                    showDialog<void>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text(function.$2),
                        content: const Text(
                          'Chức năng đang được hoàn thiện. Vui lòng quay lại sau.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Đã hiểu'),
                          ),
                        ],
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 18,
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: AppColors.primaryLight,
                          child: Icon(
                            function.$1,
                            color: AppColors.textOnPrimary,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                function.$2,
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(
                                      color: AppColors.textOnPrimary,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                function.$3,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.chevron_right,
                          color: AppColors.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
