import 'package:flutter/material.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../appointments/domain/entities/appointment.dart';
import '../../../doctors/domain/entities/time_slot.dart';
import '../../../doctors/domain/entities/work_schedule.dart';
import '../../domain/entities/doctor_workspace.dart';
import '../controllers/doctor_workspace_controller.dart';

enum DoctorAppointmentsDisplayState { loading, empty, error, data }

class _ScheduleAppointmentCounts {
  const _ScheduleAppointmentCounts({
    required this.booked,
    required this.completed,
    required this.waiting,
  });

  final int booked;
  final int completed;
  final int waiting;
}

/// Presents only appointments already verified for the signed-in doctor.
class DoctorTodayAppointmentsSection extends StatelessWidget {
  const DoctorTodayAppointmentsSection({
    super.key,
    this.state = DoctorAppointmentsDisplayState.empty,
    this.selectedDate,
    this.schedules = const [],
    this.appointments = const [],
    this.timeSlots = const [],
    this.bookings = const [],
    this.workspace,
  });
  final DoctorAppointmentsDisplayState state;
  final DateTime? selectedDate;

  /// Only pass schedules verified to belong to the authenticated doctor.
  final List<WorkSchedule> schedules;

  /// Only pass appointments verified to belong to the authenticated doctor.
  final List<Appointment> appointments;

  /// Compatibility inputs used by the existing doctor workspace flow.  The
  /// screen derives the same appointment counters from these bookings.
  final List<TimeSlot> timeSlots;
  final List<DoctorBooking> bookings;
  final DoctorWorkspaceController? workspace;

  static String _dateLabel(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  _ScheduleAppointmentCounts _countsFor(WorkSchedule schedule) {
    final source = appointments.isNotEmpty
        ? appointments
        : bookings.map((booking) => booking.appointment).toList();
    final values = source
        .where((appointment) => appointment.workScheduleId == schedule.id)
        .toList(growable: false);
    int peopleWhere(bool Function(Appointment) matches) => values
        .where(matches)
        .fold(0, (total, appointment) => total + appointment.peopleCount);
    return _ScheduleAppointmentCounts(
      booked: peopleWhere(
        (appointment) => appointment.status != AppointmentStatus.cancelled,
      ),
      completed: peopleWhere(
        (appointment) => appointment.status == AppointmentStatus.completed,
      ),
      waiting: peopleWhere(
        (appointment) =>
            appointment.status == AppointmentStatus.pending ||
            appointment.status == AppointmentStatus.confirmed,
      ),
    );
  }

  void _showDetails(
    BuildContext context,
    WorkSchedule schedule,
    _ScheduleAppointmentCounts counts,
  ) {
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
              for (final value in [
                ('Bệnh nhân đã đặt', counts.booked),
                ('Bệnh nhân đã khám', counts.completed),
                ('Bệnh nhân đang chờ', counts.waiting),
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text('${value.$1}: ${value.$2}'),
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
            _ScheduleCard(
              schedule: schedule,
              counts: _countsFor(schedule),
              onShowDetails: _showDetails,
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

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({
    required this.schedule,
    required this.counts,
    required this.onShowDetails,
  });

  final WorkSchedule schedule;
  final _ScheduleAppointmentCounts counts;
  final void Function(
    BuildContext context,
    WorkSchedule schedule,
    _ScheduleAppointmentCounts counts,
  )
  onShowDetails;

  @override
  Widget build(BuildContext context) => Card(
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
            onTap: () => onShowDetails(context, schedule, counts),
          ),
          const Divider(height: 28),
          const Text(
            'Đã đặt / Đã khám / Đang chờ',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            '${counts.booked} / ${counts.completed} / ${counts.waiting}',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textOnPrimary,
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () => onShowDetails(context, schedule, counts),
            child: const Text('Xem chi tiết ca khám'),
          ),
        ],
      ),
    ),
  );
}
