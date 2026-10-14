import 'package:flutter/material.dart';

import '../../../../core/themes/app_colors.dart';

/// Incident report UI only. Drafts are neither sent nor persisted.
class DoctorReportsPage extends StatefulWidget {
  const DoctorReportsPage({super.key, required this.selectedDate});
  final DateTime selectedDate;

  @override
  State<DoctorReportsPage> createState() => _DoctorReportsPageState();
}

class _DoctorReportsPageState extends State<DoctorReportsPage> {
  final _formKey = GlobalKey<FormState>();
  String? _issue;
  late DateTime _date = widget.selectedDate;
  bool _dateEdited = false;

  @override
  void didUpdateWidget(covariant DoctorReportsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_dateEdited) _date = widget.selectedDate;
  }

  Future<void> _chooseDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100, 12, 31),
      helpText: 'Ngày xảy ra vấn đề',
    );
    if (date != null && mounted) {
      setState(() {
        _date = date;
        _dateEdited = true;
      });
    }
  }

  Widget _heading(
    BuildContext context,
    String title,
    IconData icon, {
    bool section = false,
  }) => Row(
    children: [
      Icon(icon, size: section ? 24 : 19, color: AppColors.textOnPrimary),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          title,
          style:
              (section
                      ? Theme.of(context).textTheme.titleLarge
                      : Theme.of(context).textTheme.titleSmall)
                  ?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    key: const PageStorageKey('doctor-reports'),
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _heading(
              context,
              'Thông tin báo cáo',
              Icons.assignment_outlined,
              section: true,
            ),
            const SizedBox(height: 14),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Form(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _heading(
                        context,
                        'Loại vấn đề',
                        Icons.report_problem_outlined,
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        key: const ValueKey('doctor-report-type'),
                        isExpanded: true,
                        decoration: const InputDecoration(
                          hintText: 'Chọn loại vấn đề',
                        ),
                        items: const ['Bận đột xuất', 'Sự cố lịch làm', 'Khác']
                            .map(
                              (label) => DropdownMenuItem(
                                value: label,
                                child: Text(label),
                              ),
                            )
                            .toList(),
                        onChanged: (value) => setState(() => _issue = value),
                        validator: (_) => _issue == null
                            ? 'Vui lòng chọn loại vấn đề.'
                            : null,
                      ),
                      const SizedBox(height: 22),
                      _heading(
                        context,
                        'Ca làm liên quan',
                        Icons.work_history_outlined,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        enabled: false,
                        initialValue: 'Chưa có dữ liệu ca làm',
                        decoration: const InputDecoration(
                          helperText: 'Chỉ chọn ca đã được phân công khi dữ liệu được kết nối.',
                          helperMaxLines: 3,
                        ),
                      ),
                      const SizedBox(height: 22),
                      _heading(
                        context,
                        'Ngày xảy ra',
                        Icons.calendar_month_outlined,
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: _chooseDate,
                        icon: const Icon(Icons.event_outlined, size: 18),
                        label: Text(
                          'Ngày xảy ra: ${_date.day.toString().padLeft(2, '0')}/${_date.month.toString().padLeft(2, '0')}/${_date.year}',
                        ),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 48),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: const BorderSide(color: AppColors.border),
                        ),
                      ),
                      const SizedBox(height: 22),
                      _heading(
                        context,
                        'Nội dung và lý do',
                        Icons.subject_rounded,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        key: const ValueKey('doctor-report-reason'),
                        maxLength: 200,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Lý do',
                          hintText: 'Lý do cần Admin xử lý',
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Vui lòng nhập lý do.'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        key: const ValueKey('doctor-report-description'),
                        minLines: 4,
                        maxLines: 8,
                        maxLength: 1000,
                        decoration: const InputDecoration(
                          labelText: 'Mô tả chi tiết',
                          hintText: 'Mô tả tình huống cần Admin xử lý',
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Vui lòng nhập mô tả chi tiết.'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () {
                          FocusScope.of(context).unfocus();
                          _formKey.currentState!.validate();
                        },
                        icon: const Icon(Icons.fact_check_outlined, size: 20),
                        label: const Text('Kiểm tra biểu mẫu'),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: null,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 50),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                        ),
                        child: const Text(
                          'Gửi báo cáo cho Admin',
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Nội dung chưa được lưu hoặc gửi. Chức năng gửi báo cáo chưa được kết nối.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Lịch làm việc chỉ thay đổi sau khi Admin phê duyệt.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 26),
            _heading(
              context,
              'Báo cáo đã gửi',
              Icons.history_rounded,
              section: true,
            ),
            const SizedBox(height: 14),
            const Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: EdgeInsets.all(22),
                child: Column(
                  children: [
                    Icon(
                      Icons.inbox_outlined,
                      color: AppColors.textOnPrimary,
                      size: 32,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Chưa có dữ liệu báo cáo để hiển thị',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Lịch sử và phản hồi của Admin sẽ xuất hiện khi dữ liệu được kết nối.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
