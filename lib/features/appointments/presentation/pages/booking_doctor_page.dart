import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/widgets/view_state_widgets.dart';
import '../../../doctors/presentation/controllers/doctor_controller.dart';
import '../../../specialties/domain/entities/specialty.dart';
import 'booking_schedule_page.dart';

class BookingDoctorPage extends StatefulWidget {
  const BookingDoctorPage({super.key, required this.specialty});

  final Specialty specialty;

  @override
  State<BookingDoctorPage> createState() => _BookingDoctorPageState();
}

class _BookingDoctorPageState extends State<BookingDoctorPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DoctorController>().loadDoctorsBySpecialty(widget.specialty.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Chọn bác sĩ ${widget.specialty.name}'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: Consumer<DoctorController>(
        builder: (context, controller, child) {
          if (controller.isLoading) {
            return const AppLoadingWidget(message: 'Đang tải danh sách bác sĩ...');
          }
          if (controller.isError) {
            return AppErrorWidget(
              message: controller.errorMessage ?? 'Lỗi không xác định',
              onRetry: () => controller.loadDoctorsBySpecialty(widget.specialty.id),
            );
          }
          final doctors = controller.doctors;
          if (doctors.isEmpty) {
            return const AppEmptyWidget(message: 'Không có bác sĩ nào cho chuyên khoa này.', icon: Icons.person_off_outlined);
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: doctors.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final doctor = doctors[index];
              return InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BookingSchedulePage(doctor: doctor),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: AppColors.primarySoft,
                        backgroundImage: doctor.avatarUrl != null
                            ? NetworkImage(doctor.avatarUrl!)
                            : null,
                        child: doctor.avatarUrl == null
                            ? const Icon(Icons.person, color: AppColors.primaryDark, size: 30)
                            : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              doctor.fullName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${doctor.yearsOfExperience} năm kinh nghiệm',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Phí khám: ${doctor.consultationFee.toInt()} đ',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.primaryDark,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
