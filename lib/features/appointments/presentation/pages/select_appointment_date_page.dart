import 'package:flutter/material.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../home/presentation/widgets/patient_home_background.dart';
import '../../../specialties/domain/entities/specialty.dart';
import '../models/appointment_calendar_demo_data.dart';
import '../widgets/appointment_calendar.dart';
import '../widgets/appointment_calendar_legend.dart';

class SelectAppointmentDatePage extends StatefulWidget {
  const SelectAppointmentDatePage({
    super.key,
    required this.specialty,
    required this.onHome,
    this.availableDates,
    this.holidayDates,
    this.onDateSelected,
    this.today,
  });

  final Specialty specialty;
  final VoidCallback onHome;

  /// Null uses presentation demo dates. An empty set means no available dates.
  final Set<DateTime>? availableDates;
  final Set<DateTime>? holidayDates;
  final ValueChanged<DateTime?>? onDateSelected;

  /// Optional clock override for deterministic previews and tests.
  final DateTime? today;

  @override
  State<SelectAppointmentDatePage> createState() =>
      _SelectAppointmentDatePageState();
}

class _SelectAppointmentDatePageState extends State<SelectAppointmentDatePage> {
  late DateTime _month;
  DateTime? _selected;

  DateTime get _today => DateUtils.dateOnly(widget.today ?? DateTime.now());
  Set<DateTime> _normalize(Set<DateTime> dates) =>
      dates.map(DateUtils.dateOnly).toSet();
  Set<DateTime> get _available => widget.availableDates == null
      ? AppointmentCalendarDemoData.availableDates(_month)
      : _normalize(widget.availableDates!);
  Set<DateTime> get _holidays => widget.holidayDates == null
      ? widget.availableDates == null
            ? AppointmentCalendarDemoData.holidayDates(_month)
            : <DateTime>{}
      : _normalize(widget.holidayDates!);

  @override
  void initState() {
    super.initState();
    _month = DateTime(_today.year, _today.month);
  }

  @override
  void didUpdateWidget(covariant SelectAppointmentDatePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final currentMonth = DateTime(_today.year, _today.month);
    if (_month.isBefore(currentMonth)) _month = currentMonth;
    final selected = _selected;
    if (selected != null &&
        (selected.isBefore(_today) ||
            !(widget.availableDates == null
                    ? AppointmentCalendarDemoData.availableDates(selected)
                    : _available)
                .contains(selected))) {
      _selected = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onDateSelected?.call(null);
      });
    }
  }

  void _select(DateTime date) {
    if (date.isBefore(_today) || !_available.contains(date)) return;
    setState(() => _selected = date);
    widget.onDateSelected?.call(date);
  }

  void _changeMonth(int offset) => setState(() {
    _month = DateTime(_month.year, _month.month + offset);
  });

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
                    if (widget.availableDates == null) ...[
                      const SizedBox(height: 12),
                      const Text(
                        'Lịch minh họa — ngày khả dụng và dấu ngày lễ chưa phải dữ liệu thực tế.',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
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
