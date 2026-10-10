import 'package:flutter/material.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../home/presentation/widgets/patient_home_background.dart';
import '../../domain/entities/patient.dart';
import '../widgets/booking_history_filter_sheet.dart';
import '../widgets/health_records_date_filter.dart';

/// UI-only history for the selected profile; no appointment records are loaded.
class PatientBookingHistoryPage extends StatefulWidget {
  const PatientBookingHistoryPage({
    super.key,
    required this.patient,
    this.initialDate,
  });

  final Patient patient;
  final DateTime? initialDate;

  @override
  State<PatientBookingHistoryPage> createState() =>
      _PatientBookingHistoryPageState();
}

class _PatientBookingHistoryPageState extends State<PatientBookingHistoryPage> {
  static const _statuses = [
    'Đã thanh toán',
    'Đã tiếp nhận',
    'Đã khám',
    'Đã hủy',
  ];
  int _status = 0;
  DateTimeRange? _range;

  Future<void> _filter() async {
    final now =
        widget.initialDate ??
        DateTime.now().toUtc().add(const Duration(hours: 7));
    final result = await showModalBottomSheet<({DateTimeRange? range})>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      builder: (_) => BookingHistoryFilterSheet(
        today: DateTime(now.year, now.month, now.day),
        initialRange: _range,
      ),
    );
    if (result != null && mounted) setState(() => _range = result.range);
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
          toolbarHeight: 80 * MediaQuery.textScalerOf(context).scale(1),
          title: const Text(
            'Lịch sử đặt khám',
            maxLines: 2,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: OutlinedButton.icon(
                onPressed: _filter,
                icon: const Icon(Icons.filter_list),
                label: const Text('Lọc'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textOnPrimary,
                ),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Column(
                      children: [
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              for (
                                var index = 0;
                                index < _statuses.length;
                                index++
                              )
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ChoiceChip(
                                    label: Text(_statuses[index]),
                                    selected: _status == index,
                                    onSelected: (_) =>
                                        setState(() => _status = index),
                                    showCheckmark: false,
                                    selectedColor: AppColors.textOnPrimary,
                                    backgroundColor: AppColors.primarySoft,
                                    side: BorderSide.none,
                                    shape: const StadiumBorder(),
                                    labelStyle: TextStyle(
                                      color: _status == index
                                          ? Colors.white
                                          : AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (_range != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 8,
                            ),
                            child: Text(
                              '${HealthRecordsDateFilter.format(_range!.start)} – ${HealthRecordsDateFilter.format(_range!.end)}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppColors.textOnPrimary,
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
                                  Icons.description_outlined,
                                  size: 62,
                                  color: AppColors.disabled,
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                'Không có dữ liệu',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Các phiếu khám sẽ được hiển thị ở đây, bạn quay lại sau nhé.',
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
    ),
  );
}
