import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../domain/entities/doctor_workspace.dart';
import '../../domain/repositories/doctor_workspace_repository.dart';
import '../controllers/doctor_workspace_controller.dart';

/// Doctor incident reports work with either the legacy workspace controller or
/// the repository registered by the current dashboard.
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
  final _reason = TextEditingController();
  final _description = TextEditingController();
  String? _type, _scheduleId, _requestId, _submitError, _success;
  var _schedules = const <dynamic>[];
  var _reports = const <DoctorReport>[];
  var _loadingSchedules = false, _loadingHistory = false, _sending = false;
  String? _scheduleError, _historyError;
  DoctorWorkspaceRepository? _repository;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _repository = widget.workspace?.repository;
    _userId = widget.workspace?.userId;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _repository ??= context.read<DoctorWorkspaceRepository?>();
    _userId ??= context.read<AuthController?>()?.currentUser?.id;
    if (_repository != null &&
        _userId != null &&
        !_loadingSchedules &&
        !_loadingHistory &&
        _schedules.isEmpty &&
        _reports.isEmpty &&
        _scheduleError == null &&
        _historyError == null) {
      _loadSchedules();
      _loadHistory();
    }
  }

  @override
  void dispose() {
    _reason.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _loadSchedules() async {
    final repository = _repository, userId = _userId;
    if (repository == null || userId == null || userId.isEmpty) return;
    setState(() {
      _loadingSchedules = true;
      _scheduleError = null;
    });
    try {
      final day = await repository.loadDay(
        userId: userId,
        date: widget.selectedDate,
      );
      if (mounted) setState(() => _schedules = day.schedules);
    } catch (_) {
      if (mounted) {
        setState(() => _scheduleError = 'Không thể tải ca được phân công.');
      }
    } finally {
      if (mounted) setState(() => _loadingSchedules = false);
    }
  }

  Future<void> _loadHistory() async {
    final repository = _repository, userId = _userId;
    if (repository == null || userId == null || userId.isEmpty) return;
    setState(() {
      _loadingHistory = true;
      _historyError = null;
    });
    try {
      final reports = await repository.loadReports(userId: userId);
      if (mounted) setState(() => _reports = reports);
    } catch (_) {
      if (mounted) {
        setState(() => _historyError = 'Không thể tải lịch sử báo cáo.');
      }
    } finally {
      if (mounted) setState(() => _loadingHistory = false);
    }
  }

  Future<void> _submit() async {
    if (_sending) return;
    if (_scheduleId == null) {
      setState(() => _submitError = 'Vui lòng chọn ca được phân công.');
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    final repository = _repository, userId = _userId;
    if (repository == null || userId == null || !repository.canSubmitReports) {
      setState(() => _submitError = 'Chức năng gửi báo cáo chưa sẵn sàng.');
      return;
    }
    final requestId = _requestId ??=
        'report-${DateTime.now().microsecondsSinceEpoch}';
    setState(() {
      _sending = true;
      _submitError = null;
      _success = null;
    });
    try {
      final saved = await repository.submitReport(
        userId: userId,
        draft: DoctorReportDraft(
          type: _type!,
          scheduleId: _scheduleId!,
          date: widget.selectedDate,
          reason: _reason.text.trim(),
          description: _description.text.trim(),
          requestId: requestId,
        ),
      );
      if (!mounted) return;
      setState(() {
        _reports = [saved, ..._reports];
        _success = 'Đã gửi báo cáo. Đang chờ Admin xử lý.';
        _sending = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _sending = false;
          _submitError =
              'Gửi báo cáo thất bại. Nội dung được giữ lại để bạn thử lại.';
        });
      }
    }
  }

  String _scheduleLabel(dynamic schedule) =>
      '${schedule.startTime ?? '—'} - ${schedule.endTime ?? '—'}';
  String _status(DoctorReportStatus status) => switch (status) {
    DoctorReportStatus.pending => 'Chờ xử lý',
    DoctorReportStatus.approved => 'Đã phê duyệt',
    DoctorReportStatus.rejected => 'Đã từ chối',
    DoctorReportStatus.resolved => 'Đã xử lý',
    DoctorReportStatus.unknown => 'Không xác định',
  };

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    key: const PageStorageKey('doctor-reports'),
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Thông tin báo cáo',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DropdownButtonFormField<String>(
                        key: const ValueKey('doctor-report-type'),
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Loại vấn đề',
                        ),
                        initialValue: _type,
                        items: const ['Bận đột xuất', 'Sự cố lịch làm', 'Khác']
                            .map(
                              (item) => DropdownMenuItem(
                                value: item,
                                child: Text(item),
                              ),
                            )
                            .toList(),
                        onChanged: _sending
                            ? null
                            : (value) => setState(() => _type = value),
                        validator: (value) =>
                            value == null ? 'Vui lòng chọn loại vấn đề.' : null,
                      ),
                      const SizedBox(height: 16),
                      if (_loadingSchedules)
                        const Center(child: CircularProgressIndicator())
                      else if (_scheduleError != null)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _scheduleError!,
                              style: const TextStyle(color: AppColors.error),
                            ),
                            TextButton(
                              onPressed: _loadSchedules,
                              child: const Text('Thử lại tải ca'),
                            ),
                          ],
                        )
                      else
                        DropdownButtonFormField<String>(
                          key: const ValueKey('doctor-report-schedule'),
                          isExpanded: true,
                          initialValue: _scheduleId,
                          decoration: const InputDecoration(
                            labelText: 'Ca làm liên quan',
                          ),
                          items: _schedules
                              .map(
                                (schedule) => DropdownMenuItem<String>(
                                  value: schedule.id as String,
                                  child: Text(_scheduleLabel(schedule)),
                                ),
                              )
                              .toList(),
                          onChanged: _sending
                              ? null
                              : (value) => setState(() => _scheduleId = value),
                        ),
                      const SizedBox(height: 16),
                      Text(
                        'Ngày xảy ra: ${widget.selectedDate.day.toString().padLeft(2, '0')}/${widget.selectedDate.month.toString().padLeft(2, '0')}/${widget.selectedDate.year}',
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        key: const ValueKey('doctor-report-reason'),
                        controller: _reason,
                        maxLength: 200,
                        decoration: const InputDecoration(labelText: 'Lý do'),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Vui lòng nhập lý do.'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        key: const ValueKey('doctor-report-description'),
                        controller: _description,
                        minLines: 4,
                        maxLines: 8,
                        maxLength: 1000,
                        decoration: const InputDecoration(
                          labelText: 'Mô tả chi tiết',
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Vui lòng nhập mô tả chi tiết.'
                            : null,
                      ),
                      if (_submitError != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            _submitError!,
                            style: const TextStyle(color: AppColors.error),
                          ),
                        ),
                      if (_success != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            _success!,
                            style: const TextStyle(color: Colors.green),
                          ),
                        ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _sending || _success != null
                            ? null
                            : _submit,
                        child: Text(
                          _sending
                              ? 'Đang gửi báo cáo…'
                              : 'Gửi báo cáo cho Admin',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 26),
            Text(
              'Báo cáo đã gửi',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            if (_loadingHistory)
              const Center(child: CircularProgressIndicator())
            else if (_historyError != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _historyError!,
                    style: const TextStyle(color: AppColors.error),
                  ),
                  TextButton(
                    onPressed: _loadHistory,
                    child: const Text('Thử lại lịch sử'),
                  ),
                ],
              )
            else if (_reports.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(22),
                  child: Text(
                    'Chưa có dữ liệu báo cáo để hiển thị',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              for (final report in _reports)
                Card(
                  child: ListTile(
                    title: Text(report.reason),
                    subtitle: Text(
                      '${_status(report.status)}${report.adminResponse == null ? '' : '\n${report.adminResponse}'}',
                    ),
                  ),
                ),
          ],
        ),
      ),
    ),
  );
}
