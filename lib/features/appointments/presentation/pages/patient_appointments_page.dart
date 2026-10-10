import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/widgets/view_state_widgets.dart';
import '../../../profile/presentation/controllers/patient_profile_controller.dart';
import 'appointment_history_page.dart';

/// Entry point from Home. The history page owns the live appointment stream.
class PatientAppointmentsPage extends StatelessWidget {
  const PatientAppointmentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<PatientProfileController?>();
    final patient = profile?.patient;
    if (patient != null) {
      return AppointmentHistoryPage(
        patientId: patient.id,
        patientName: patient.fullName,
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Lịch đặt khám'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: profile?.isLoading == true
          ? const AppLoadingWidget(message: 'Đang tải hồ sơ bệnh nhân...')
          : AppEmptyWidget(
              message: profile?.isError == true
                  ? (profile?.errorMessage ?? 'Không thể tải hồ sơ bệnh nhân.')
                  : 'Vui lòng cập nhật thông tin cá nhân để xem lịch khám.',
              icon: Icons.person_off_outlined,
              onRetry: profile?.isError == true
                  ? profile?.refreshPatient
                  : null,
            ),
    );
  }
}
