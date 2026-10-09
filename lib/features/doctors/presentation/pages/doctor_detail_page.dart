import 'package:flutter/material.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../home/presentation/widgets/patient_home_background.dart';
import '../models/doctor_detail_ui_model.dart';
import '../widgets/doctor_detail_section.dart';
import '../widgets/doctor_detail_timeline.dart';
import '../widgets/doctor_overview_card.dart';

class DoctorDetailPage extends StatelessWidget {
  const DoctorDetailPage({super.key, required this.doctor});
  final DoctorDetailUiModel doctor;

  @override
  Widget build(BuildContext context) => Theme(
    data: Theme.of(context).copyWith(
      textTheme: Theme.of(context).textTheme.apply(fontFamily: 'BeVietnamPro'),
    ),
    child: PatientHomeBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: AppColors.textOnPrimary,
          title: const Text(
            'Thông tin bác sĩ',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        body: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  DoctorOverviewCard(doctor: doctor),
                  const SizedBox(height: 20),
                  DoctorDetailSection(
                    title: 'Lịch khám bệnh',
                    initiallyExpanded: true,
                    child: doctor.schedule.isEmpty
                        ? const Text(
                            'Chưa có thông tin lịch khám.',
                            style: TextStyle(color: AppColors.textSecondary),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                doctor.specialty,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              for (final schedule in doctor.schedule)
                                Container(
                                  width: double.infinity,
                                  margin: const EdgeInsets.only(top: 12),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.primarySoft,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          Text(
                                            schedule.day,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.textOnPrimary,
                                            ),
                                          ),
                                          Text(
                                            '• ${schedule.session}',
                                            style: const TextStyle(
                                              color: AppColors.textOnPrimary,
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (schedule.location.isNotEmpty) ...[
                                        const SizedBox(height: 6),
                                        Text(
                                          schedule.location,
                                          style: const TextStyle(
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                            ],
                          ),
                  ),
                  if (doctor.education.isNotEmpty)
                    DoctorDetailSection(
                      title: 'Quá trình đào tạo',
                      child: DoctorDetailTimeline(items: doctor.education),
                    ),
                  if (doctor.clinicalExperience.isNotEmpty ||
                      doctor.teachingExperience.isNotEmpty)
                    DoctorDetailSection(
                      title: 'Quá trình công tác',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (doctor.clinicalExperience.isNotEmpty) ...[
                            const Text(
                              'Kinh nghiệm khám, chữa bệnh',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 12),
                            DoctorDetailTimeline(
                              items: doctor.clinicalExperience,
                            ),
                          ],
                          if (doctor.teachingExperience.isNotEmpty) ...[
                            if (doctor.clinicalExperience.isNotEmpty)
                              const SizedBox(height: 20),
                            const Text(
                              'Kinh nghiệm giảng dạy',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 12),
                            DoctorDetailTimeline(
                              items: doctor.teachingExperience,
                            ),
                          ],
                        ],
                      ),
                    ),
                  if (doctor.associations.isNotEmpty)
                    DoctorDetailSection(
                      title: 'Hiệp hội chuyên môn',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final association in doctor.associations)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                '• $association',
                                style: const TextStyle(height: 1.5),
                              ),
                            ),
                        ],
                      ),
                    ),
                  if (doctor.research.isNotEmpty)
                    DoctorDetailSection(
                      title: 'Công trình nghiên cứu',
                      child: DoctorDetailTimeline(items: doctor.research),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
