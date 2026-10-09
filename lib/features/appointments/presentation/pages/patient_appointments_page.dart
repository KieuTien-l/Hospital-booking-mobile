import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../../../core/state/view_state.dart';
import '../../../../core/themes/app_colors.dart';
import '../../../../core/widgets/view_state_widgets.dart';
import '../../domain/entities/appointment.dart';
import '../../../profile/presentation/controllers/patient_profile_controller.dart';
import '../controllers/appointment_controller.dart';

class PatientAppointmentsPage extends StatefulWidget {
  const PatientAppointmentsPage({super.key});

  @override
  State<PatientAppointmentsPage> createState() => _PatientAppointmentsPageState();
}

class _PatientAppointmentsPageState extends State<PatientAppointmentsPage> {
  String? _loadedPatientId;
  bool _showUpcoming = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAppointmentsFor(context.read<PatientProfileController?>()?.patient?.id);
    });
  }

  void _loadAppointmentsFor(String? patientId) {
    if (!mounted ||
        patientId == null ||
        patientId.isEmpty ||
        patientId == _loadedPatientId) {
      return;
    }
    _loadedPatientId = patientId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _loadedPatientId == patientId) {
        context.read<AppointmentController>().loadAppointments(patientId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<PatientProfileController?>();
    final patient = profile?.patient;
    _loadAppointmentsFor(patient?.id);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Lịch đặt khám'),
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
                        : 'Vui lòng cập nhật thông tin cá nhân để xem lịch khám.',
                    icon: Icons.person_off_outlined,
                    onRetry: profile?.isError == true
                        ? profile?.refreshPatient
                        : null,
                  )
          : Consumer<AppointmentController>(
              builder: (context, controller, child) {
                if (controller.appointmentsStatus == ViewState.loading) {
                  return const AppLoadingWidget(message: 'Đang tải lịch khám...');
                }
                if (controller.appointmentsStatus == ViewState.error) {
                  return AppErrorWidget(
                    message: controller.appointmentsErrorMessage ?? 'Lỗi không xác định',
                    onRetry: () => controller.loadAppointments(patient.id),
                  );
                }
                final appointments = _showUpcoming
                    ? controller.upcomingAppointments
                    : controller.pastAppointments;
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                      child: SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(value: true, label: Text('Sắp tới')),
                          ButtonSegment(value: false, label: Text('Đã qua')),
                        ],
                        selected: {_showUpcoming},
                        onSelectionChanged: (selected) => setState(
                          () => _showUpcoming = selected.first,
                        ),
                      ),
                    ),
                    Expanded(
                      child: appointments.isEmpty
                          ? AppEmptyWidget(
                              message: _showUpcoming
                                  ? 'Bạn chưa có lịch khám sắp tới.'
                                  : 'Bạn chưa có lịch khám trong quá khứ.',
                              icon: Icons.event_busy_outlined,
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: appointments.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                          final appt = appointments[index];
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
                                appt.appointmentDate == null
                                    ? 'Chưa xác định ngày khám'
                                    : DateFormat('dd/MM/yyyy').format(
                                        appt.appointmentDate!,
                                      ),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primaryDark,
                                  fontSize: 16,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.primarySoft,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${appt.startTime ?? '--:--'} - ${appt.endTime ?? '--:--'}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primaryDark,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Icon(Icons.person, size: 16, color: AppColors.textSecondary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Mã bác sĩ: ${appt.doctorId}',
                                  style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.info_outline, size: 16, color: AppColors.textSecondary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Trạng thái: ${_statusLabel(appt.status)}',
                                  style: const TextStyle(color: AppColors.textSecondary),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                          );
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
    );
  }

  String _statusLabel(AppointmentStatus status) => switch (status) {
    AppointmentStatus.pending => 'Chờ xác nhận',
    AppointmentStatus.confirmed => 'Đã xác nhận',
    AppointmentStatus.completed => 'Đã hoàn thành',
    AppointmentStatus.cancelled => 'Đã hủy',
    AppointmentStatus.noShow => 'Vắng mặt',
    AppointmentStatus.unknown => 'Chưa xác định',
  };
}
