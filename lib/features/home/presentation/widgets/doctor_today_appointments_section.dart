import 'package:flutter/material.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../doctors/domain/entities/work_schedule.dart';

enum DoctorAppointmentsDisplayState { loading, empty, error, data }

/// Presentation states only; no doctor appointment source is connected yet.
class DoctorTodayAppointmentsSection extends StatelessWidget {
  const DoctorTodayAppointmentsSection({
    super.key,
    this.state = DoctorAppointmentsDisplayState.empty,
    this.selectedDate,
    this.schedules = const [],
  });
  final DoctorAppointmentsDisplayState state;
  final DateTime? selectedDate;

  /// Only pass schedules verified to belong to the authenticated doctor.
  final List<WorkSchedule> schedules;

  static String _dateLabel(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  void _showDetails(BuildContext context, WorkSchedule schedule) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Chi tiết lịch làm việc',
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              Text('Mã: ${schedule.id}'),
              const SizedBox(height: 12),
              Text(
                'Ngày: ${schedule.workDate == null ? 'Chưa có dữ liệu' : _dateLabel(schedule.workDate!)}',
              ),
              const SizedBox(height: 12),
              Text(
                'Thời gian: ${schedule.startTime ?? '—'} – ${schedule.endTime ?? '—'}',
              ),
              const SizedBox(height: 12),
              Text(
                'Trạng thái: ${schedule.status.trim().isEmpty ? 'Chưa có dữ liệu' : schedule.status}',
              ),
              const SizedBox(height: 20),
              for (final label in const [
                'Bệnh nhân đã đặt',
                'Bệnh nhân đã khám',
                'Bệnh nhân đang chờ',
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text('$label: Chưa có dữ liệu'),
                ),
              const Text(
                'Thống kê tổng hợp sẽ hiển thị khi nguồn dữ liệu và cách tính được xác minh.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Đóng'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loading = state == DoctorAppointmentsDisplayState.loading;
    final error = state == DoctorAppointmentsDisplayState.error;
    final visibleSchedules = schedules
        .where(
          (schedule) =>
              selectedDate == null ||
              DateUtils.isSameDay(schedule.workDate, selectedDate),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(
              Icons.medical_services_outlined,
              size: 24,
              color: AppColors.textOnPrimary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Các ca khám',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (state == DoctorAppointmentsDisplayState.data &&
            visibleSchedules.isNotEmpty)
          for (final schedule in visibleSchedules)
            Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.schedule_rounded,
                        color: AppColors.textOnPrimary,
                      ),
                      title: Text(
                        'Lịch ${schedule.id}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        '${schedule.startTime ?? '—'} – ${schedule.endTime ?? '—'}',
                      ),
                      onTap: () => _showDetails(context, schedule),
                    ),
                    const Divider(height: 28),
                    const Text(
                      'Đã đặt / Đã khám / Đang chờ',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '— / — / —',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textOnPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: () => _showDetails(context, schedule),
                      child: const Text('Xem chi tiết ca khám'),
                    ),
                  ],
                ),
              ),
            )
        else
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                children: [
                  if (loading)
                    const SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(
                        color: AppColors.textOnPrimary,
                        semanticsLabel: 'Đang tải lịch khám',
                      ),
                    )
                  else
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: AppColors.primarySoft,
                      child: Icon(
                        error
                            ? Icons.cloud_off_rounded
                            : Icons.event_note_rounded,
                        size: 26,
                        color: AppColors.textOnPrimary,
                      ),
                    ),
                  const SizedBox(height: 16),
                  Text(
                    loading
                        ? 'Đang tải lịch khám'
                        : error
                        ? 'Không thể tải lịch khám'
                        : selectedDate == null
                        ? 'Chưa có dữ liệu lịch khám để hiển thị'
                        : 'Chưa có dữ liệu ca làm để hiển thị',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    loading
                        ? 'Vui lòng chờ trong giây lát.'
                        : error
                        ? 'Lịch khám hiện chưa thể hiển thị. Vui lòng quay lại sau.'
                        : 'Lịch và ca làm cho ngày đang chọn sẽ xuất hiện khi dữ liệu được kết nối.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
