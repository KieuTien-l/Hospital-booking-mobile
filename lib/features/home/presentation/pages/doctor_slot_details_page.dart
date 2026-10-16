import 'package:flutter/material.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../appointments/domain/entities/appointment.dart';
import '../../../doctors/domain/entities/time_slot.dart';
import '../../../doctors/domain/entities/work_schedule.dart';
import '../models/doctor_slot_booking.dart';
import '../widgets/doctor_dashboard_stat_card.dart';
import '../widgets/patient_home_background.dart';
import '../controllers/doctor_workspace_controller.dart';
import '../models/doctor_slot_availability.dart';
import '../../domain/entities/doctor_workspace.dart';

class DoctorSlotDetailsPage extends StatefulWidget {
  const DoctorSlotDetailsPage({
    super.key,
    required this.schedule,
    required this.slot,
    this.bookings,
    this.isDemo = false,
    this.workspace,
  });

  final WorkSchedule schedule;
  final TimeSlot slot;

  /// Null means the booking source has not been connected; [] is a known empty list.
  final List<DoctorSlotBooking>? bookings;
  final bool isDemo;
  final DoctorWorkspaceController? workspace;

  @override
  State<DoctorSlotDetailsPage> createState() => _DoctorSlotDetailsPageState();
}

class _DoctorSlotDetailsPageState extends State<DoctorSlotDetailsPage> {
  WorkSchedule get _schedule =>
      widget.workspace?.data?.schedules
          .where((schedule) => schedule.id == widget.schedule.id)
          .firstOrNull ??
      widget.schedule;
  TimeSlot get _slot =>
      widget.workspace?.data?.slots
          .where((slot) => slot.id == widget.slot.id)
          .firstOrNull ??
      widget.slot;
  List<DoctorSlotBooking>? get _sourceBookings => widget.workspace == null
      ? widget.bookings
      : widget.workspace?.data?.bookings;
  String _query = '';
  int _filter = 0;

  bool _waiting(DoctorSlotBooking booking) =>
      booking.appointment.status == AppointmentStatus.confirmed;

  List<DoctorSlotBooking> get _bookings {
    final validSlot =
        _slot.workScheduleId == _schedule.id &&
        _slot.doctorId == _schedule.doctorId;
    final result = (_sourceBookings ?? const <DoctorSlotBooking>[]).where((
      booking,
    ) {
      final appointment = booking.appointment;
      return validSlot &&
          appointment.doctorId == _schedule.doctorId &&
          appointment.workScheduleId == _schedule.id &&
          appointment.timeSlotId == _slot.id &&
          appointment.appointmentDate != null &&
          _schedule.workDate != null &&
          DateUtils.isSameDay(
            appointment.appointmentDate,
            _schedule.workDate,
          ) &&
          appointment.status != AppointmentStatus.cancelled;
    }).toList();
    result.sort(
      (a, b) => (a.appointment.queueNumber ?? 1 << 30).compareTo(
        b.appointment.queueNumber ?? 1 << 30,
      ),
    );
    return result;
  }

  String _dateLabel(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  Widget _pill(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .09),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      text,
      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
    ),
  );

  Widget _heading(BuildContext context, String title, IconData icon) => Row(
    children: [
      Icon(icon, color: AppColors.textOnPrimary, size: 22),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontFamily: 'BeVietnamPro',
          ),
        ),
      ),
    ],
  );

  Widget _patientCard(DoctorSlotBooking booking) {
    final appointment = booking.appointment;
    final (status, color) = switch (appointment.status) {
      AppointmentStatus.completed => ('Đã khám', const Color(0xFF318653)),
      AppointmentStatus.pending => ('Chờ xác nhận', const Color(0xFFB87520)),
      AppointmentStatus.confirmed => ('Chờ khám', AppColors.textOnPrimary),
      AppointmentStatus.noShow => ('Vắng mặt', AppColors.textSecondary),
      _ => ('Chưa rõ trạng thái', AppColors.textSecondary),
    };
    return Card(
      key: ValueKey('doctor-booking-${appointment.id}'),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    appointment.queueNumber?.toString().padLeft(2, '0') ?? '—',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textOnPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        booking.patientName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        [
                          if (booking.gender != null) booking.gender!,
                          if (booking.birthYear != null)
                            'Sinh năm ${booking.birthYear}',
                        ].join(' • '),
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _pill(status, color),
                      if (appointment.peopleCount > 1) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Số người khám: ${appointment.peopleCount}',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 26),
            Text(
              'Mã bệnh nhân: ${appointment.patientId}',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Lý do khám',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              appointment.reason?.trim().isNotEmpty == true
                  ? appointment.reason!
                  : 'Chưa cung cấp',
              style: const TextStyle(fontSize: 14, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.workspace == null
      ? _build(context)
      : ListenableBuilder(
          listenable: widget.workspace!,
          builder: (context, _) => _build(context),
        );

  Widget _build(BuildContext context) {
    final workspace = widget.workspace;
    if (workspace?.data != null &&
        !workspace!.data!.slots.any((slot) => slot.id == widget.slot.id)) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chi tiết ca khám')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Ca khám không còn trong lịch được phân công.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    final bookings = _bookings;
    final connected = _sourceBookings != null;
    final totals = DoctorBookingTotals.fromBookings(bookings);
    final completed = totals.completed;
    final waiting = totals.waiting;
    final query = _query.trim().toLowerCase();
    final visible = bookings
        .where(
          (booking) =>
              (_filter == 0 ||
                  (_filter == 1
                      ? _waiting(booking)
                      : _filter == 2
                      ? booking.appointment.status ==
                            AppointmentStatus.completed
                      : booking.appointment.status ==
                            AppointmentStatus.pending)) &&
              (booking.patientName.toLowerCase().contains(query) ||
                  booking.appointment.patientId.toLowerCase().contains(query)),
        )
        .toList();
    final date = _schedule.workDate;
    final morning =
        (int.tryParse(_slot.startTime?.split(':').first ?? '') ?? 12) < 12;
    final capacity = _slot.capacity;
    final booked = _slot.bookedCount;
    final availability = DoctorSlotAvailability.fromSlot(_slot);
    final full = availability != DoctorSlotAvailability.available;
    final status = availability.label;
    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: Theme.of(context).textTheme
            .apply(fontFamily: 'BeVietnamPro'),
      ),
      child: PatientHomeBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            leading: const BackButton(),
            backgroundColor: Colors.transparent,
            title: const Text(
              'Chi tiết ca khám',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
          ),
          body: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (workspace?.isLoading == true)
                        const LinearProgressIndicator(),
                      if (workspace?.hasError == true)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              children: [
                                Text(
                                  'Không thể cập nhật danh sách. ${workspace!.errorMessage ?? ''}',
                                  textAlign: TextAlign.center,
                                ),
                                TextButton(
                                  onPressed: workspace.refresh,
                                  child: const Text('Thử lại'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (workspace != null)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: workspace.isLoading
                                ? null
                                : workspace.refresh,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Làm mới'),
                          ),
                        ),
                      Card(
                        margin: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.calendar_month_outlined,
                                    color: AppColors.textOnPrimary,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      date == null
                                          ? 'Chưa có ngày khám'
                                          : _dateLabel(date),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                '${_slot.startTime ?? '—'} - ${_slot.endTime ?? '—'}',
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textOnPrimary,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _pill(
                                    morning ? 'Buổi sáng' : 'Buổi chiều',
                                    morning
                                        ? const Color(0xFF318653)
                                        : const Color(0xFFCC7B2B),
                                  ),
                                  _pill(
                                    status,
                                    full
                                        ? AppColors.textSecondary
                                        : AppColors.textOnPrimary,
                                  ),
                                ],
                              ),
                              const Divider(height: 28),
                              Text(
                                'Đã đặt: ${booked ?? '—'} / ${capacity ?? '—'} chỗ',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                              if (capacity != null &&
                                  capacity > 0 &&
                                  booked != null) ...[
                                const SizedBox(height: 10),
                                LinearProgressIndicator(
                                  value: (booked / capacity).clamp(0.0, 1.0),
                                  minHeight: 6,
                                  borderRadius: BorderRadius.circular(6),
                                  color: full
                                      ? AppColors.textSecondary
                                      : AppColors.primaryDark,
                                  backgroundColor: AppColors.primarySoft,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      if (widget.isDemo) ...[
                        const SizedBox(height: 14),
                        const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              size: 18,
                              color: AppColors.textOnPrimary,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Dữ liệu mẫu • Thông tin bệnh nhân chỉ để minh họa giao diện.',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 20),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final columns =
                              MediaQuery.textScalerOf(context).scale(14) > 20
                              ? 1
                              : totals.pending > 0
                              ? 2
                              : 3;
                          return Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              for (final stat in [
                                (
                                  'Đã đặt',
                                  Icons.event_available_outlined,
                                  totals.booked,
                                ),
                                ('Đã khám', Icons.done_all_rounded, completed),
                                ('Chờ khám', Icons.schedule_rounded, waiting),
                                if (totals.pending > 0)
                                  (
                                    'Chờ xác nhận',
                                    Icons.pending_actions,
                                    totals.pending,
                                  ),
                              ])
                                SizedBox(
                                  width:
                                      (constraints.maxWidth -
                                          (columns - 1) * 10) /
                                      columns,
                                  child: DoctorDashboardStatCard(
                                    label: stat.$1,
                                    icon: stat.$2,
                                    value: connected ? stat.$3 : null,
                                    isLoading:
                                        workspace?.isLoading == true &&
                                        !connected,
                                    hasError:
                                        workspace?.hasError == true &&
                                        !connected,
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 26),
                      _heading(
                        context,
                        'Danh sách bệnh nhân',
                        Icons.people_outline_rounded,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Các lịch đã đặt trong khung giờ này, sắp xếp theo số thứ tự.',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (bookings.isNotEmpty) ...[
                        TextField(
                          key: const ValueKey('doctor-booking-search'),
                          onChanged: (value) => setState(() => _query = value),
                          decoration: const InputDecoration(
                            hintText: 'Tìm tên hoặc mã bệnh nhân',
                            prefixIcon: Icon(Icons.search_rounded),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final (index, title) in [
                              'Tất cả',
                              'Chờ khám',
                              'Đã khám',
                              if (totals.pending > 0) 'Chờ xác nhận',
                            ].indexed)
                              ChoiceChip(
                                label: Text(title),
                                selected: _filter == index,
                                onSelected: (_) =>
                                    setState(() => _filter = index),
                                selectedColor: AppColors.primaryLight,
                                backgroundColor: AppColors.surface,
                                labelStyle: const TextStyle(
                                  color: AppColors.textOnPrimary,
                                  fontSize: 12,
                                ),
                                side: const BorderSide(color: AppColors.border),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (visible.isEmpty)
                        Card(
                          margin: EdgeInsets.zero,
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              children: [
                                const CircleAvatar(
                                  radius: 26,
                                  backgroundColor: AppColors.primarySoft,
                                  child: Icon(
                                    Icons.person_search_outlined,
                                    color: AppColors.textOnPrimary,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  workspace?.isLoading == true && !connected
                                      ? 'Đang tải danh sách khám'
                                      : workspace?.hasError == true &&
                                            !connected
                                      ? 'Không thể tải danh sách khám'
                                      : !connected
                                      ? 'Chưa có dữ liệu danh sách khám'
                                      : bookings.isEmpty
                                      ? 'Chưa có bệnh nhân đặt ca này'
                                      : 'Không tìm thấy bệnh nhân',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    height: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  !connected
                                      ? 'Danh sách sẽ hiển thị khi dữ liệu lịch hẹn được kết nối.'
                                      : bookings.isEmpty
                                      ? 'Các lịch hẹn sẽ xuất hiện tại đây khi ca khám có người đặt.'
                                      : 'Thử tên, mã bệnh nhân hoặc trạng thái khác.',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 13,
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        ...visible.map(_patientCard),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
