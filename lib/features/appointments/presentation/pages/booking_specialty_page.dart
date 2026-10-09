import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/widgets/view_state_widgets.dart';
import '../../../specialties/presentation/controllers/specialty_controller.dart';
import 'booking_doctor_page.dart';

class BookingSpecialtyPage extends StatefulWidget {
  const BookingSpecialtyPage({super.key});

  @override
  State<BookingSpecialtyPage> createState() => _BookingSpecialtyPageState();
}

class _BookingSpecialtyPageState extends State<BookingSpecialtyPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SpecialtyController>().loadSpecialties();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Chọn chuyên khoa'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: Consumer<SpecialtyController>(
        builder: (context, controller, child) {
          if (controller.isLoading) {
            return const AppLoadingWidget(message: 'Đang tải dữ liệu...');
          }
          if (controller.isError) {
            return AppErrorWidget(
              message: controller.errorMessage ?? 'Lỗi không xác định',
              onRetry: () => controller.loadSpecialties(),
            );
          }
          final specialties = controller.specialties;
          if (specialties.isEmpty) {
            return const AppEmptyWidget(message: 'Không có chuyên khoa nào.', icon: Icons.medical_services_outlined);
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: specialties.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final specialty = specialties[index];
              return InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BookingDoctorPage(specialty: specialty),
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
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: AppColors.primarySoft,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: specialty.imageUrl != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  specialty.imageUrl!,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : const Icon(Icons.medical_services, color: AppColors.primaryDark),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              specialty.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              specialty.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
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
