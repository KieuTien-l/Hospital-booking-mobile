import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/widgets/view_state_widgets.dart';
import '../../../profile/presentation/controllers/patient_profile_controller.dart';
import '../controllers/health_record_controller.dart';

class HealthRecordsPage extends StatefulWidget {
  const HealthRecordsPage({super.key});

  @override
  State<HealthRecordsPage> createState() => _HealthRecordsPageState();
}

class _HealthRecordsPageState extends State<HealthRecordsPage> {
  String? _loadedPatientId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRecordsFor(context.read<PatientProfileController?>()?.patient?.id);
    });
  }

  void _loadRecordsFor(String? patientId) {
    if (!mounted ||
        patientId == null ||
        patientId.isEmpty ||
        patientId == _loadedPatientId) {
      return;
    }
    _loadedPatientId = patientId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _loadedPatientId == patientId) {
        context.read<HealthRecordController>().loadRecords(patientId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<PatientProfileController?>();
    final patient = profile?.patient;
    _loadRecordsFor(patient?.id);
    
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Hồ sơ sức khỏe'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: patient == null
          ? profile?.isLoading == true
                ? const AppLoadingWidget(message: 'Đang tải hồ sơ bệnh nhân...')
                : AppEmptyWidget(
                    message: profile?.isError == true
                        ? (profile?.errorMessage ??
                              'Không thể tải hồ sơ bệnh nhân.')
                        : 'Vui lòng cập nhật hồ sơ bệnh nhân để xem hồ sơ sức khỏe.',
                    icon: Icons.person_off_outlined,
                    onRetry: profile?.isError == true
                        ? profile?.refreshPatient
                        : null,
                  )
          : Consumer<HealthRecordController>(
              builder: (context, controller, child) {
                if (controller.isLoading) {
                  return const AppLoadingWidget(message: 'Đang tải hồ sơ sức khỏe...');
                }
                if (controller.isError) {
                  return AppErrorWidget(
                    message: controller.errorMessage ?? 'Lỗi không xác định',
                    onRetry: () => controller.loadRecords(patient.id),
                  );
                }
                final records = controller.records;
                if (records.isEmpty) {
                  return const AppEmptyWidget(message: 'Chưa có hồ sơ sức khỏe nào.', icon: Icons.favorite_border_rounded);
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: records.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final record = records[index];
                    return Container(
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                DateFormat('dd/MM/yyyy HH:mm').format(record.recordDate),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                              const Icon(Icons.favorite, color: AppColors.error, size: 16),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Chẩn đoán: ${record.diagnosis}',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          if (record.prescription != null && record.prescription!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Đơn thuốc: ${record.prescription}',
                              style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                            ),
                          ],
                          if (record.notes != null && record.notes!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Ghi chú: ${record.notes}',
                              style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
