import 'package:flutter/material.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../profile/presentation/widgets/health_records_date_filter.dart';

class AppointmentHistoryFilterSheet extends StatefulWidget {
  const AppointmentHistoryFilterSheet({
    super.key,
    required this.today,
    this.initialRange,
    this.initialSpecialty,
    this.specialties = const {},
    this.lastDate,
  });

  final DateTime today;
  final DateTime? lastDate;
  final Map<String, String> specialties;
  final String? initialSpecialty;
  final DateTimeRange? initialRange;

  @override
  State<AppointmentHistoryFilterSheet> createState() =>
      _AppointmentHistoryFilterSheetState();
}

class _AppointmentHistoryFilterSheetState
    extends State<AppointmentHistoryFilterSheet> {
  late DateTime _from;
  late DateTime _to;
  bool _hasRange = false;
  String? _specialty;

  void _reset() {
    _to = widget.today;
    final lastDay = DateTime(_to.year - 1, _to.month + 1, 0).day;
    _from = DateTime(
      _to.year - 1,
      _to.month,
      _to.day > lastDay ? lastDay : _to.day,
    );
    _hasRange = false;
    _specialty = null;
  }

  @override
  void initState() {
    super.initState();
    _reset();
    _specialty = widget.specialties.containsKey(widget.initialSpecialty)
        ? widget.initialSpecialty
        : null;
    final range = widget.initialRange;
    if (range != null) {
      _from = range.start;
      _to = range.end;
      _hasRange = true;
    }
  }

  Future<void> _pick(bool from) async {
    final date = await showDatePicker(
      context: context,
      helpText: from ? 'Chọn ngày bắt đầu' : 'Chọn ngày kết thúc',
      initialDate: from ? _from : _to,
      firstDate: from ? DateTime(1900) : _from,
      lastDate: from
          ? _to
          : (widget.lastDate ?? DateTime(widget.today.year + 10, 12, 31)),
    );
    if (date == null || !mounted) return;
    setState(() {
      if (from) {
        _from = date;
      } else {
        _to = date;
      }
      _hasRange = true;
    });
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Lọc lịch sử đặt khám',
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                tooltip: 'Đóng',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Lọc theo ngày'),
            value: _hasRange,
            onChanged: (value) => setState(() => _hasRange = value),
          ),
          if (_hasRange)
            HealthRecordsDateFilter(
              fromDate: _from,
              toDate: _to,
              onFromTap: () => _pick(true),
              onToTap: () => _pick(false),
            ),
          if (widget.specialties.isNotEmpty) ...[
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              key: ValueKey(_specialty),
              initialValue: _specialty ?? '',
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Chuyên khoa'),
              items: [
                const DropdownMenuItem(
                  value: '',
                  child: Text('Tất cả chuyên khoa'),
                ),
                for (final entry in widget.specialties.entries)
                  DropdownMenuItem(value: entry.key, child: Text(entry.value)),
              ],
              onChanged: (value) =>
                  setState(() => _specialty = value == '' ? null : value),
            ),
          ],
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              OutlinedButton(
                onPressed: () => setState(_reset),
                child: const Text('Đặt lại'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.textOnPrimary,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.of(context).pop(
                  // A result wrapper distinguishes Apply without dates from dismissing.
                  (
                    specialtyId: _specialty,
                    range: _hasRange
                        ? DateTimeRange(start: _from, end: _to)
                        : null,
                  ),
                ),
                child: const Text('Áp dụng'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
