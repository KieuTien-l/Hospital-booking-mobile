import 'package:flutter/material.dart';

import '../../../../core/themes/app_colors.dart';
import '../../domain/entities/doctor_workspace.dart';
import '../controllers/doctor_workspace_controller.dart';
import '../controllers/doctor_reports_controller.dart';

/// Incident report UI only. Drafts are neither sent nor persisted.
class DoctorReportsPage extends StatefulWidget {
  const DoctorReportsPage({
    super.key,
    required this.selectedDate,
    this.workspace,
  });
  final DateTime selectedDate;
  final DoctorWorkspaceController? workspace;

  @override
  State<DoctorReportsPage> createState() => _DoctorReportsPageState();
}

class _DoctorReportsPageState extends State<DoctorReportsPage> {
  final _formKey = GlobalKey<FormState>();
  String? _issue;
  late DateTime _date = widget.selectedDate;
  bool _dateEdited = false;
  DoctorReportsController? _reports;
  String? _scheduleId;
  final _reason = TextEditingController();
  final _description = TextEditingController();
  String? _requestId;
  String? _sent;

  @override
  void initState() {
    super.initState();
    final workspace = widget.workspace;
    if (workspace != null) {
      _reports = DoctorReportsController(
        repository: workspace.repository,
        userId: workspace.userId,
      );
      _reports!.loadHistory();
      _reports!.loadSchedules(_date);
      _reports!.addListener(_changed);
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _reports?.removeListener(_changed);
    _reports?.dispose();
    _reason.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    FocusScope.of(context).unfocus();
    if (_reports == null ||
        _reports!.sending ||
        !_formKey.currentState!.validate()) {
      return;
    }
    _requestId ??=
        '${widget.workspace!.userId}-${DateTime.now().microsecondsSinceEpoch}';
    // Keep this submitted draft's date stable if the home tab changes day.
    _dateEdited = true;
    final success = await _reports!.send(
      DoctorReportDraft(
        type: _issue!,
        scheduleId: _scheduleId!,
        date: _date,
        reason: _reason.text.trim(),
        description: _description.text.trim(),
        requestId: _requestId!,
      ),
    );
    if (!mounted) return;
    if (success) {
      setState(() {
        _sent = 'Đã gửi báo cáo. Đang chờ Admin xử lý.';
        _requestId = null;
      });
    }
  }

  void _edited() {
    _requestId = null;
    _sent = null;
  }

  @override
  void didUpdateWidget(covariant DoctorReportsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_dateEdited && _date != widget.selectedDate) {
      _date = widget.selectedDate;
      _scheduleId = null;
      _edited();
      _reports?.loadSchedules(_date);
    }
  }

  Future<void> _chooseDate() async {
    final date = await showDatePicker(
      context: context,
      useRootNavigator: false,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100, 12, 31),
      helpText: 'Ngày xảy ra vấn đề',
    );
    if (date != null && mounted) {
      setState(() {
        _date = date;
        _dateEdited = true;
        _scheduleId = null;
        _edited();
      });
      _reports?.loadSchedules(date);
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

  Widget _historyCard(DoctorReport report) {
    final label = switch (report.status) {
      DoctorReportStatus.pending => 'Chờ xử lý',
      DoctorReportStatus.approved => 'Đã phê duyệt',
      DoctorReportStatus.rejected => 'Đã từ chối',
      DoctorReportStatus.resolved => 'Đã xử lý',
      DoctorReportStatus.unknown => 'Chưa rõ trạng thái',
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              report.type,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              '${report.date.day}/${report.date.month}/${report.date.year} • $label',
              style: const TextStyle(color: AppColors.textOnPrimary),
            ),
            const SizedBox(height: 10),
            Text(report.reason),
            if (report.adminResponse?.trim().isNotEmpty == true) ...[
              const Divider(height: 24),
              const Text(
                'Phản hồi Admin',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Text(report.adminResponse!),
            ],
          ],
        ),
      ),
    );
  }

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
                        onChanged: _reports?.sending == true
                            ? null
                            : (value) => setState(() {
                                _issue = value;
                                _edited();
                              }),
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
                      if (_reports?.loadingSchedules == true)
                        const LinearProgressIndicator(),
                      if (_reports?.scheduleError != null) ...[
                        Text(_reports!.scheduleError!),
                        TextButton(
                          onPressed: () => _reports!.loadSchedules(_date),
                          child: const Text('Thử lại tải ca'),
                        ),
                      ],
                      if (_reports?.repository.canSubmitReports == true)
                        DropdownButtonFormField<String>(
                          key: ValueKey('doctor-report-schedule-$_date'),
                          initialValue: _scheduleId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            hintText: 'Chọn ca được phân công',
                          ),
                          items: [
                            for (final schedule in _reports!.schedules)
                              DropdownMenuItem(
                                value: schedule.id,
                                child: Text(
                                  '${schedule.startTime ?? '—'} - ${schedule.endTime ?? '—'}',
                                ),
                              ),
                          ],
                          onChanged:
                              _reports!.sending || _reports!.loadingSchedules
                              ? null
                              : (value) => setState(() {
                                  _scheduleId = value;
                                  _edited();
                                }),
                          validator: (value) =>
                              value == null ||
                                  !_reports!.schedules.any(
                                    (schedule) => schedule.id == value,
                                  )
                              ? 'Vui lòng chọn ca được phân công.'
                              : null,
                        )
                      else
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
                        onPressed: _reports?.sending == true
                            ? null
                            : _chooseDate,
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
                        controller: _reason,
                        readOnly: _reports?.sending == true,
                        onChanged: (_) => setState(_edited),
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
                        controller: _description,
                        readOnly: _reports?.sending == true,
                        onChanged: (_) => setState(_edited),
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
                        onPressed:
                            _reports?.repository.canSubmitReports == true &&
                                _reports?.sending == false &&
                                _sent == null
                            ? _send
                            : null,
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
                        child: Text(
                          _reports?.sending == true
                              ? 'Đang gửi báo cáo…'
                              : 'Gửi báo cáo cho Admin',
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _sent ??
                            _reports?.sendError ??
                            (_reports?.repository.canSubmitReports == true
                                ? 'Báo cáo chỉ được gửi khi bạn nhấn nút gửi.'
                                : 'Nội dung chưa được lưu hoặc gửi. Chức năng gửi báo cáo chưa được kết nối.'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
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
            if (_reports?.repository.canSubmitReports == true)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _reports!.loading ? null : _reports!.loadHistory,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Làm mới lịch sử'),
                ),
              ),
            const SizedBox(height: 14),
            if (_reports?.loading == true) const LinearProgressIndicator(),
            if (_reports?.error != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(_reports!.error!),
                      TextButton(
                        onPressed: _reports!.loadHistory,
                        child: const Text('Thử lại lịch sử'),
                      ),
                    ],
                  ),
                ),
              ),
            if (_reports?.reports.isNotEmpty == true)
              ..._reports!.reports.map(_historyCard)
            else if (_reports?.loading != true && _reports?.error == null)
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
