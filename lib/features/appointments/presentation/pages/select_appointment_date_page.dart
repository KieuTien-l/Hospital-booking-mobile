import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../doctors/domain/repositories/doctor_repository.dart';
import '../../../doctors/presentation/controllers/schedule_controller.dart';
import '../../../home/presentation/widgets/patient_home_background.dart';
import '../../../specialties/domain/entities/specialty.dart';
import '../models/appointment_calendar_demo_data.dart';
import '../widgets/appointment_calendar.dart';
import '../widgets/appointment_calendar_legend.dart';
import 'select_appointment_time_page.dart';

class SelectAppointmentDatePage extends StatefulWidget {
  const SelectAppointmentDatePage({
    super.key,
    required this.specialty,
    required this.onHome,
    this.availableDates,
    this.holidayDates,
    this.onDateSelected,
    this.today,
    this.useDemoData = true,
  });

  final Specialty specialty;
  final VoidCallback onHome;

  /// Null uses presentation demo dates. An empty set means no available dates.
  final Set<DateTime>? availableDates;
  final Set<DateTime>? holidayDates;
  final ValueChanged<DateTime?>? onDateSelected;

  /// Optional clock override for deterministic previews and tests.
  final DateTime? today;

  /// Production selects a start date; availability is loaded on the next page.
  final bool useDemoData;

  @override
  State<SelectAppointmentDatePage> createState() =>
      _SelectAppointmentDatePageState();
}

class _SelectAppointmentDatePageState extends State<SelectAppointmentDatePage> {
  late DateTime _month;
  DateTime? _selected;
  Set<DateTime> _liveAvailableDates = <DateTime>{};
  bool _loadingLiveAvailability = false;
  String? _liveAvailabilityError;
  int _availabilityRequest = 0;

  DateTime get _today => DateUtils.dateOnly(widget.today ?? DateTime.now());
  bool get _loadsLiveAvailability =>
      widget.availableDates == null && !widget.useDemoData;
  Set<DateTime> _normalize(Set<DateTime> dates) =>
      dates.map(DateUtils.dateOnly).toSet();
  Set<DateTime> get _available {
    if (widget.availableDates != null) {
      return _normalize(widget.availableDates!);
    }
    if (widget.useDemoData) {
      return AppointmentCalendarDemoData.availableDates(_month);
    }
    return _liveAvailableDates;
  }

  Set<DateTime> get _holidays => widget.holidayDates == null
      ? widget.availableDates == null && widget.useDemoData
            ? AppointmentCalendarDemoData.holidayDates(_month)
            : <DateTime>{}
      : _normalize(widget.holidayDates!);

  @override
  void initState() {
    super.initState();
    _month = DateTime(_today.year, _today.month);
    if (_loadsLiveAvailability) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _loadLiveAvailability(),
      );
    }
  }

  @override
  void didUpdateWidget(covariant SelectAppointmentDatePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final currentMonth = DateTime(_today.year, _today.month);
    if (_month.isBefore(currentMonth)) _month = currentMonth;
    final selected = _selected;
    if (selected != null &&
        (selected.isBefore(_today) || !_available.contains(selected))) {
      _selected = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onDateSelected?.call(null);
      });
    }
    if (_loadsLiveAvailability &&
        (oldWidget.specialty.id != widget.specialty.id ||
            oldWidget.useDemoData != widget.useDemoData ||
            oldWidget.availableDates != widget.availableDates)) {
      _loadLiveAvailability();
    }
  }

  void _select(DateTime date) {
    if (date.isBefore(_today) || !_available.contains(date)) return;
    setState(() => _selected = date);
    widget.onDateSelected?.call(date);
  }

  void _changeMonth(int offset) {
    var selectionCleared = false;
    setState(() {
      _month = DateTime(_month.year, _month.month + offset);
      if (_selected != null &&
          (_selected!.year != _month.year ||
              _selected!.month != _month.month)) {
        _selected = null;
        selectionCleared = true;
      }
    });
    if (selectionCleared) widget.onDateSelected?.call(null);
    if (_loadsLiveAvailability) _loadLiveAvailability();
  }

  Future<void> _loadLiveAvailability() async {
    if (!_loadsLiveAvailability) return;
    final request = ++_availabilityRequest;
    final visibleMonth = DateTime(_month.year, _month.month);
    setState(() {
      _loadingLiveAvailability = true;
      _liveAvailabilityError = null;
    });
    try {
      final doctorRepository = context.read<DoctorRepository?>();
      final scheduleController = context.read<ScheduleController?>();
      if (doctorRepository == null || scheduleController == null) {
        throw StateError('Không thể tải dữ liệu lịch khám.');
      }
      final doctors = await doctorRepository.getDoctorsBySpecialty(
        widget.specialty.id,
      );
      final dayCount = DateUtils.getDaysInMonth(
        visibleMonth.year,
        visibleMonth.month,
      );
      final schedules = await scheduleController.loadWeeklySchedulesForDoctors(
        doctors: doctors,
        startDate: visibleMonth,
        days: dayCount,
      );
      final dates = <DateTime>{
        for (final byDay in schedules.values)
          for (final entry in byDay.entries)
            if (entry.value.isNotEmpty && !entry.key.isBefore(_today))
              DateUtils.dateOnly(entry.key),
      };
      if (!mounted || request != _availabilityRequest) return;
      final selected = _selected;
      final selectionCleared =
          selected != null && !dates.contains(DateUtils.dateOnly(selected));
      setState(() {
        _liveAvailableDates = dates;
        _loadingLiveAvailability = false;
        if (selectionCleared) _selected = null;
      });
      if (selectionCleared) widget.onDateSelected?.call(null);
    } catch (_) {
      if (!mounted || request != _availabilityRequest) return;
      setState(() {
        _liveAvailableDates = <DateTime>{};
        _loadingLiveAvailability = false;
        _liveAvailabilityError = 'Không thể tải ngày có lịch khám.';
      });
    }
  }

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
          leading: const BackButton(color: AppColors.textOnPrimary),
          title: const Text(
            'Chọn ngày khám',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          actions: [
            IconButton(
              tooltip: 'Về trang chủ',
              onPressed: widget.onHome,
              icon: const Icon(
                Icons.home_outlined,
                color: AppColors.textOnPrimary,
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.specialty.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: AppointmentCalendar(
                          month: _month,
                          today: _today,
                          availableDates: _available,
                          holidayDates: _holidays,
                          selectedDate: _selected,
                          onDateSelected: _select,
                          onPreviousMonth:
                              _month.isAfter(
                                DateTime(_today.year, _today.month),
                              )
                              ? () => _changeMonth(-1)
                              : null,
                          onNextMonth: () => _changeMonth(1),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const AppointmentCalendarLegend(),
                    if (_loadsLiveAvailability && _loadingLiveAvailability)
                      const Padding(
                        padding: EdgeInsets.only(top: 16),
                        child: LinearProgressIndicator(),
                      ),
                    if (_loadsLiveAvailability &&
                        _liveAvailabilityError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Không thể tải ngày có lịch khám.',
                                style: TextStyle(color: AppColors.error),
                              ),
                            ),
                            TextButton(
                              onPressed: _loadLiveAvailability,
                              child: const Text('Thử lại'),
                            ),
                          ],
                        ),
                      ),
                    if (_loadsLiveAvailability &&
                        !_loadingLiveAvailability &&
                        _liveAvailabilityError == null &&
                        _liveAvailableDates.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: Text(
                          'Chưa có khung giờ trống trong tháng này.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    if (_selected != null) ...[
                      const SizedBox(height: 12),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          'Ngày đã chọn: ${_selected!.day.toString().padLeft(2, '0')}/${_selected!.month.toString().padLeft(2, '0')}/${_selected!.year}',
                          style: const TextStyle(
                            color: AppColors.textOnPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                    if (widget.availableDates == null &&
                        widget.useDemoData) ...[
                      const SizedBox(height: 12),
                      const Text(
                        'Lịch minh họa — ngày khả dụng và dấu ngày lễ chưa phải dữ liệu thực tế.',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        key: const ValueKey('continue-date'),
                        onPressed: _selected == null
                            ? null
                            : () => Navigator.of(context).push<void>(
                                MaterialPageRoute(
                                  settings: RouteSettings(
                                    arguments: ModalRoute.of(context)
                                        ?.settings
                                        .arguments,
                                  ),
                                  builder: (_) => SelectAppointmentTimePage(
                                    specialty: widget.specialty,
                                    initialDate: _selected!,
                                  ),
                                ),
                              ),
                        child: const Text('TIẾP TỤC'),
                      ),
                    ),
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
