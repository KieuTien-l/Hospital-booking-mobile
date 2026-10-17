import 'package:flutter/material.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../appointments/domain/entities/appointment.dart';
import '../../../doctors/domain/entities/time_slot.dart';
import '../../../doctors/domain/entities/work_schedule.dart';
import '../models/doctor_slot_booking.dart';
import '../pages/doctor_slot_details_page.dart';

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

/// Displays schedules that are already scoped to the authenticated doctor.
///
/// The standalone preview uses explicitly supplied sample bookings. In the live
/// app, patient names are deliberately not fetched here; the doctor receives
/// only the schedule and appointment fields they are authorised to read.
class DoctorTodayAppointmentsSection extends StatelessWidget {
  const DoctorTodayAppointmentsSection({
    super.key,
    this.state = DoctorAppointmentsDisplayState.empty,
    this.selectedDate,
    this.schedules = const [],
    this.timeSlots = const [],
    this.appointments = const [],
    this.bookings,
    this.isDemo = false,
  });

  final DoctorAppointmentsDisplayState state;
  final DateTime? selectedDate;
  final List<WorkSchedule> schedules;
  final List<TimeSlot> timeSlots;
  final List<Appointment> appointments;
  final List<DoctorSlotBooking>? bookings;
  final bool isDemo;

  static String _dateLabel(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  static int? _minutes(String? time) {
    final parts = time?.split(':');
    if (parts == null || parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null ||
        minute == null ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59) {
      return null;
    }
    return hour * 60 + minute;
  }

  _ScheduleAppointmentCounts _countsFor(WorkSchedule schedule) {
    final values = appointments
        .where(
          (appointment) =>
              appointment.workScheduleId == schedule.id &&
              appointment.doctorId == schedule.doctorId,
        )
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

  List<DoctorSlotBooking> _bookingsFor(WorkSchedule schedule) {
    final source =
        bookings ??
        appointments
            .map(
              (appointment) => DoctorSlotBooking(
                appointment: appointment,
                patientName: appointment.queueNumber == null
                    ? 'Bệnh nhân đã đặt lịch'
                    : 'Bệnh nhân #${appointment.queueNumber}',
              ),
            )
            .toList(growable: false);
    return source
        .where(
          (booking) =>
              booking.appointment.workScheduleId == schedule.id &&
              booking.appointment.doctorId == schedule.doctorId,
        )
        .toList(growable: false);
  }

  List<Widget> _sessions(BuildContext context, List<WorkSchedule> visible) {
    final groups = <(DateTime?, bool?), List<(WorkSchedule, TimeSlot?)>>{};
    for (final schedule in visible) {
      final slots = <TimeSlot?>[
        ...timeSlots.where(
          (slot) =>
              slot.workScheduleId == schedule.id &&
              slot.doctorId == schedule.doctorId,
        ),
      ];
      if (slots.isEmpty) slots.add(null);
      final date = schedule.workDate == null
          ? null
          : DateUtils.dateOnly(schedule.workDate!);
      for (final slot in slots) {
        final minutes = _minutes(slot?.startTime ?? schedule.startTime);
        final key = (date, minutes == null ? null : minutes < 12 * 60);
        groups.putIfAbsent(key, () => []).add((schedule, slot));
      }
    }
    final keys = groups.keys.toList()
      ..sort((a, b) {
        final dateOrder = (a.$1 ?? DateTime(0)).compareTo(b.$1 ?? DateTime(0));
        if (dateOrder != 0) return dateOrder;
        int order(bool? morning) => morning == null
            ? 2
            : morning
            ? 0
            : 1;
        return order(a.$2).compareTo(order(b.$2));
      });

    return [
      for (final key in keys)
        Card(
          margin: const EdgeInsets.only(bottom: 14),
          color: AppColors.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: AppColors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${key.$1 == null ? 'Chưa có ngày' : _dateLabel(key.$1!)} - '
                  '${key.$2 == null
                      ? 'Lịch khám'
                      : key.$2!
                      ? 'Buổi sáng'
                      : 'Buổi chiều'}'
                  '${key.$1 == null ? '' : ' (${key.$1!.weekday == DateTime.sunday ? 'Chủ nhật' : 'Thứ ${key.$1!.weekday + 1}'})'}',
                  style: TextStyle(
                    color: key.$2 == true
                        ? const Color(0xFF318653)
                        : const Color(0xFFCC7B2B),
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final entries = groups[key]!
                      ..sort(
                        (a, b) =>
                            (_minutes(a.$2?.startTime ?? a.$1.startTime) ??
                                    1440)
                                .compareTo(
                                  _minutes(b.$2?.startTime ?? b.$1.startTime) ??
                                      1440,
                                ),
                      );
                    final columns =
                        constraints.maxWidth < 240 ||
                            MediaQuery.textScalerOf(context).scale(14) > 20
                        ? 1
                        : 2;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (final entry in entries)
                          SizedBox(
                            width:
                                (constraints.maxWidth - (columns - 1) * 12) /
                                columns,
                            child: _slotCard(context, entry.$1, entry.$2),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
    ];
  }

  Widget _slotCard(
    BuildContext context,
    WorkSchedule schedule,
    TimeSlot? slot,
  ) {
    final full =
        slot != null &&
        (slot.status == TimeSlotStatus.booked ||
            (slot.capacity != null &&
                slot.bookedCount != null &&
                slot.bookedCount! >= slot.capacity!));
    final available = !full && slot != null && slot.isAvailable;
    final label = full
        ? 'Đã đặt hết'
        : available
        ? null
        : slot == null
        ? 'Chưa có dữ liệu ca khám'
        : 'Chưa có chỗ khả dụng';
    final time =
        '${slot?.startTime ?? schedule.startTime ?? '—'} - '
        '${slot?.endTime ?? schedule.endTime ?? '—'}';
    return Semantics(
      button: true,
      label: '$time, ${label ?? 'Còn chỗ'}, xem chi tiết',
      excludeSemantics: true,
      child: Material(
        key: ValueKey('doctor-slot-${slot?.id ?? schedule.id}'),
        color: available ? AppColors.primarySoft : AppColors.divider,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () {
            if (slot == null) {
              _showDetails(context, schedule, _countsFor(schedule));
              return;
            }
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => DoctorSlotDetailsPage(
                  schedule: schedule,
                  slot: slot,
                  bookings: _bookingsFor(schedule),
                  isDemo: isDemo,
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(14),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 72),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    time,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: available
                          ? AppColors.primaryDark
                          : AppColors.textSecondary,
                    ),
                  ),
                  if (label != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
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
              if (isDemo) ...[
                const Text('Dữ liệu mẫu • Chỉ để xem giao diện'),
                const SizedBox(height: 12),
              ],
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
        .toList(growable: false);
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
        if (isDemo) ...[
          const Text(
            'Dữ liệu mẫu • Chỉ để xem giao diện',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
        ],
        if (state == DoctorAppointmentsDisplayState.data &&
            visibleSchedules.isNotEmpty)
          ..._sessions(context, visibleSchedules)
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
                        : isDemo && selectedDate?.weekday == DateTime.sunday
                        ? 'Chủ nhật không có ca khám'
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
                        : isDemo && selectedDate?.weekday == DateTime.sunday
                        ? 'Vui lòng chọn ngày khác để xem các ca khám.'
                        : isDemo
                        ? 'Không có ca khám mẫu cho ngày đang chọn. Vui lòng chọn ngày khác.'
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
