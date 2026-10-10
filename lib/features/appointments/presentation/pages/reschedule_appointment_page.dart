import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/widgets/view_state_widgets.dart';
import '../../../doctors/domain/entities/doctor.dart';
import '../../../doctors/domain/entities/time_slot.dart';
import '../../../doctors/domain/repositories/doctor_repository.dart';
import '../../../doctors/presentation/controllers/schedule_controller.dart';
import '../../../home/presentation/widgets/patient_home_background.dart';
import '../../domain/entities/appointment.dart';
import '../controllers/appointment_controller.dart';
import '../models/appointment_time_ui_models.dart';
import '../widgets/appointment_date_strip.dart';
import '../widgets/appointment_time_slot_grid.dart';

/// Lets a patient choose a different available slot for the same doctor.
class RescheduleAppointmentPage extends StatefulWidget {
  const RescheduleAppointmentPage({super.key, required this.appointment});

  final Appointment appointment;

  @override
  State<RescheduleAppointmentPage> createState() =>
      _RescheduleAppointmentPageState();
}

class _RescheduleAppointmentPageState extends State<RescheduleAppointmentPage> {
  static const _daysToShow = 14;

  final Map<DateTime, List<AppointmentTimeOption>> _slotsByDate = {};
  late DateTime _startDate;
  DateTime? _selectedDate;
  AppointmentTimeOption? _selectedSlot;
  Doctor? _doctor;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  List<DateTime> get _dates => List.generate(
    _daysToShow,
    (index) => _startDate.add(Duration(days: index)),
    growable: false,
  );

  @override
  void initState() {
    super.initState();
    final today = DateUtils.dateOnly(
      DateTime.now().toUtc().add(const Duration(hours: 7)),
    );
    final currentDate = widget.appointment.appointmentDate;
    _startDate = currentDate != null && currentDate.isAfter(today)
        ? DateUtils.dateOnly(currentDate)
        : today;
    _selectedDate = _startDate;
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSchedules());
  }

  Future<void> _loadSchedules() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final doctorRepository = context.read<DoctorRepository>();
      final scheduleController = context.read<ScheduleController>();
      final doctor = await doctorRepository.getDoctorById(
        widget.appointment.doctorId,
      );
      if (doctor == null) {
        throw StateError('Bác sĩ không còn khả dụng để thay đổi lịch.');
      }
      final schedules = await scheduleController.loadWeeklySchedulesForDoctors(
        doctors: [doctor],
        startDate: _startDate,
        days: _daysToShow,
      );
      if (!mounted) return;

      final mapped = <DateTime, List<AppointmentTimeOption>>{};
      for (final date in _dates) {
        final normalizedDate = DateUtils.dateOnly(date);
        final slots =
            schedules[doctor.id]?[normalizedDate] ?? const <TimeSlot>[];
        mapped[normalizedDate] = [
          for (final slot in slots)
            if (slot.id != widget.appointment.timeSlotId)
              AppointmentTimeOption(
                id: slot.id,
                workScheduleId: slot.workScheduleId,
                label:
                    '${slot.startTime ?? '--:--'} – ${slot.endTime ?? '--:--'}',
                startTime: slot.startTime,
                endTime: slot.endTime,
                available: slot.isAvailable,
              ),
        ];
      }
      final firstAvailable = mapped.entries
          .where((entry) => entry.value.isNotEmpty)
          .map((entry) => entry.key)
          .firstOrNull;
      setState(() {
        _doctor = doctor;
        _slotsByDate
          ..clear()
          ..addAll(mapped);
        _selectedDate = firstAvailable ?? _startDate;
        _selectedSlot = null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _submit() async {
    final date = _selectedDate;
    final slot = _selectedSlot;
    if (date == null ||
        slot == null ||
        slot.startTime == null ||
        slot.endTime == null) {
      return;
    }
    setState(() => _saving = true);
    final updated = await context
        .read<AppointmentController>()
        .rescheduleAppointment(
          appointmentId: widget.appointment.id,
          newWorkScheduleId: slot.workScheduleId,
          newTimeSlotId: slot.id,
          newDate: date,
          newStartTime: slot.startTime!,
          newEndTime: slot.endTime!,
        );
    if (!mounted) return;
    setState(() => _saving = false);
    if (updated == null) {
      _showMessage(
        context.read<AppointmentController>().errorMessage ??
            'Không thể thay đổi lịch hẹn. Vui lòng thử lại.',
      );
      return;
    }
    _showMessage('Đã thay đổi lịch hẹn. Lịch mới đang chờ xác nhận.');
    Navigator.of(context).pop(true);
  }

  void _showMessage(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) => Theme(
    data: Theme.of(context).copyWith(
      textTheme: Theme.of(context).textTheme.apply(fontFamily: 'BeVietnamPro'),
    ),
    child: PatientHomeBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: AppColors.textOnPrimary,
          title: const Text(
            'Thay đổi lịch hẹn',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        body: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: _loading
                  ? const AppLoadingWidget(message: 'Đang tải lịch trống...')
                  : _error != null
                  ? AppErrorWidget(message: _error!, onRetry: _loadSchedules)
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Text(
                          _doctor == null
                              ? 'Chọn khung giờ mới'
                              : 'Bác sĩ ${_doctor!.fullName}',
                          style: const TextStyle(
                            color: AppColors.textOnPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Chỉ các khung giờ còn trống mới có thể được chọn.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 20),
                        AppointmentDateStrip(
                          dates: _dates,
                          selected: _selectedDate ?? _startDate,
                          onSelected: (date) => setState(() {
                            _selectedDate = date;
                            _selectedSlot = null;
                          }),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          _selectedDate == null
                              ? 'Chọn một ngày'
                              : 'Khung giờ ngày ${appointmentDateLabel(_selectedDate!)}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 12),
                        AppointmentTimeSlotGrid(
                          slots: _selectedDate == null
                              ? const []
                              : _slotsByDate[_selectedDate!] ?? const [],
                          selectedId: _selectedSlot?.id,
                          onSelected: (slot) =>
                              setState(() => _selectedSlot = slot),
                        ),
                        const SizedBox(height: 28),
                        FilledButton(
                          key: const ValueKey('confirm-reschedule'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primaryDark,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                          ),
                          onPressed: _saving || _selectedSlot == null
                              ? null
                              : _submit,
                          child: _saving
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Xác nhận thay đổi lịch'),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    ),
  );
}
