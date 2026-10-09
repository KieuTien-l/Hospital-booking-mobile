import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/widgets/view_state_widgets.dart';
import '../../../profile/presentation/controllers/patient_profile_controller.dart';
import '../controllers/test_result_controller.dart';

class TestResultsPage extends StatefulWidget {
  const TestResultsPage({super.key});

  @override
  State<TestResultsPage> createState() => _TestResultsPageState();
}

class _TestResultsPageState extends State<TestResultsPage> {
  String? _loadedPatientId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadResultsFor(context.read<PatientProfileController?>()?.patient?.id);
    });
  }

  void _loadResultsFor(String? patientId) {
    if (!mounted ||
        patientId == null ||
        patientId.isEmpty ||
        patientId == _loadedPatientId) {
      return;
    }
    _loadedPatientId = patientId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _loadedPatientId == patientId) {
        context.read<TestResultController>().loadResults(patientId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<PatientProfileController?>();
    final patient = profile?.patient;
    _loadResultsFor(patient?.id);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Kết quả cận lâm sàng'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: patient == null
          ? _profileState(profile)
          : Consumer<TestResultController>(
              builder: (context, controller, _) {
                if (controller.isLoading) {
                  return const AppLoadingWidget(
                    message: 'Đang tải kết quả cận lâm sàng...',
                  );
                }
                if (controller.isError) {
                  return AppErrorWidget(
                    message: controller.errorMessage ?? 'Không thể tải kết quả.',
                    onRetry: () => controller.loadResults(patient.id),
                  );
                }
                if (controller.results.isEmpty) {
                  return const AppEmptyWidget(
                    message: 'Bạn chưa có kết quả cận lâm sàng nào.',
                    icon: Icons.science_outlined,
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: controller.results.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (_, index) {
                    final result = controller.results[index];
                    return Card(
                      elevation: 0,
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.biotech_outlined,
                                  color: AppColors.primaryDark,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    result.testName.isEmpty
                                        ? 'Xét nghiệm chưa có tên'
                                        : result.testName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              result.resultDescription.isEmpty
                                  ? 'Chưa có mô tả kết quả.'
                                  : result.resultDescription,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                height: 1.45,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              DateFormat('dd/MM/yyyy').format(result.testDate),
                              style: const TextStyle(
                                color: AppColors.primaryDark,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
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

  Widget _profileState(PatientProfileController? profile) {
    if (profile?.isLoading == true) {
      return const AppLoadingWidget(message: 'Đang tải hồ sơ bệnh nhân...');
    }
    return AppEmptyWidget(
      message: profile?.isError == true
          ? (profile?.errorMessage ?? 'Không thể tải hồ sơ bệnh nhân.')
          : 'Vui lòng cập nhật hồ sơ bệnh nhân để xem kết quả.',
      icon: Icons.person_off_outlined,
      onRetry: profile?.isError == true ? profile?.refreshPatient : null,
    );
  }
}
