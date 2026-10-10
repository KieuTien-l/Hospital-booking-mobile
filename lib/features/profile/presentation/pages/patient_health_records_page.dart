import 'package:flutter/material.dart';

import '../../../../core/themes/app_colors.dart';
import '../../domain/entities/patient.dart';
import '../widgets/health_records_date_filter.dart';

/// Front-end history filters. No records are loaded until data integration.
class PatientHealthRecordsPage extends StatefulWidget {
  const PatientHealthRecordsPage({
    super.key,
    required this.patient,
    this.initialDate,
  });

  final Patient patient;
  final DateTime? initialDate;

  @override
  State<PatientHealthRecordsPage> createState() =>
      _PatientHealthRecordsPageState();
}

class _PatientHealthRecordsPageState extends State<PatientHealthRecordsPage> {
  static const _tabs = ['Khám bệnh', 'Nhập viện', 'Khám sức khỏe'];
  static const _categories = ['Đơn thuốc', 'Phiếu chỉ định', 'Chứng nhận'];
  int _tab = 0;
  int _category = 0;
  late final DateTime _today;
  late DateTime _from;
  late DateTime _to;

  @override
  void initState() {
    super.initState();
    // HealWay's client timezone is Asia/Saigon (UTC+7).
    final now =
        widget.initialDate ??
        DateTime.now().toUtc().add(const Duration(hours: 7));
    _today = DateTime(now.year, now.month, now.day);
    _to = _today;
    final lastDay = DateTime(now.year - 1, now.month + 1, 0).day;
    _from = DateTime(
      now.year - 1,
      now.month,
      now.day > lastDay ? lastDay : now.day,
    );
  }

  Future<void> _pickDate(bool from) async {
    final picked = await showDatePicker(
      context: context,
      helpText: from ? 'Chọn ngày bắt đầu' : 'Chọn ngày kết thúc',
      initialDate: from ? _from : _to,
      firstDate: from ? DateTime(1900) : _from,
      lastDate: from ? _to : _today,
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (from) {
        _from = picked;
      } else {
        _to = picked;
      }
    });
  }

  String get _emptyMessage => switch (_tab) {
    0 => 'Vui lòng thử điều chỉnh bộ lọc ngày hoặc chọn danh mục khác để xem kết quả.',
    1 => 'Vui lòng thử điều chỉnh bộ lọc ngày để xem kết quả.',
    _ => 'Vui lòng thử điều chỉnh bộ lọc ngày để xem kết quả khám sức khỏe.',
  };

  @override
  Widget build(BuildContext context) => Theme(
    data: Theme.of(context).copyWith(
      textTheme: Theme.of(context).textTheme.apply(fontFamily: 'BeVietnamPro'),
    ),
    child: Scaffold(
      backgroundColor: AppColors.primarySoft,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        toolbarHeight: 88,
        centerTitle: true,
        title: Column(
          children: [
            Text(
              widget.patient.fullName.toUpperCase(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              '(${widget.patient.id})',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                        child: Card(
                          margin: EdgeInsets.zero,
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Row(
                              children: [
                                for (
                                  var index = 0;
                                  index < _tabs.length;
                                  index++
                                )
                                  Expanded(
                                    child: Semantics(
                                      selected: _tab == index,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(12),
                                        onTap: () =>
                                            setState(() => _tab = index),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 4,
                                            vertical: 14,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _tab == index
                                                ? AppColors.primarySoft
                                                : Colors.transparent,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Column(
                                            children: [
                                              Text(
                                                _tabs[index],
                                                textAlign: TextAlign.center,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodyMedium
                                                    ?.copyWith(
                                                      color: _tab == index
                                                          ? AppColors
                                                                .textOnPrimary
                                                          : AppColors
                                                                .textSecondary,
                                                      fontWeight: _tab == index
                                                          ? FontWeight.w700
                                                          : FontWeight.w400,
                                                    ),
                                              ),
                                              const SizedBox(height: 8),
                                              Container(
                                                height: 3,
                                                width: 36,
                                                decoration: BoxDecoration(
                                                  color: _tab == index
                                                      ? AppColors.textOnPrimary
                                                      : AppColors.divider,
                                                  borderRadius:
                                                      BorderRadius.circular(3),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: HealthRecordsDateFilter(
                          fromDate: _from,
                          toDate: _to,
                          onFromTap: () => _pickDate(true),
                          onToTap: () => _pickDate(false),
                        ),
                      ),
                      if (_tab == 0)
                        ColoredBox(
                          color: AppColors.surface,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            child: Row(
                              children: [
                                for (
                                  var index = 0;
                                  index < _categories.length;
                                  index++
                                )
                                  Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: ChoiceChip(
                                      label: Text(_categories[index]),
                                      selected: _category == index,
                                      onSelected: (_) =>
                                          setState(() => _category = index),
                                      showCheckmark: false,
                                      selectedColor: AppColors.textOnPrimary,
                                      backgroundColor: AppColors.primarySoft,
                                      side: BorderSide.none,
                                      shape: const StadiumBorder(),
                                      labelStyle: TextStyle(
                                        color: _category == index
                                            ? Colors.white
                                            : AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          28,
                          constraints.maxHeight * .16,
                          28,
                          48,
                        ),
                        child: Column(
                          children: [
                            const CircleAvatar(
                              radius: 52,
                              backgroundColor: AppColors.background,
                              child: Icon(
                                Icons.find_in_page_outlined,
                                size: 62,
                                color: AppColors.disabled,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Không có kết quả!',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textSecondary,
                                  ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              _emptyMessage,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: AppColors.textSecondary,
                                    height: 1.6,
                                  ),
                            ),
                          ],
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
    ),
  );
}
