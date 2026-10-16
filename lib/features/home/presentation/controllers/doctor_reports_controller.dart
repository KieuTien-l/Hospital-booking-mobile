import 'package:flutter/foundation.dart';

import '../../../doctors/domain/entities/work_schedule.dart';
import '../../domain/entities/doctor_workspace.dart';
import '../../domain/repositories/doctor_workspace_repository.dart';
import 'doctor_workspace_controller.dart';

class DoctorReportsController extends ChangeNotifier {
  DoctorReportsController({required this.repository, required this.userId});
  final DoctorWorkspaceRepository repository;
  final String userId;
  List<DoctorReport> reports = const [];
  List<WorkSchedule> schedules = const [];
  bool loading = false, loadingSchedules = false, sending = false;
  String? error, scheduleError, sendError;
  bool _disposed = false;
  int _historyRequest = 0, _scheduleRequest = 0;
  DateTime? scheduleDate;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> loadHistory() async {
    final token = ++_historyRequest;
    loading = true;
    error = null;
    _notify();
    try {
      final result = await repository.loadReports(userId: userId);
      if (_disposed || token != _historyRequest) return;
      reports = List.unmodifiable(result);
    } catch (failure) {
      if (failure is DoctorWorkspaceAccessException) reports = const [];
      if (!_disposed && token == _historyRequest) {
        error = 'Không thể tải lịch sử báo cáo.';
      }
    }
    if (!_disposed && token == _historyRequest) {
      loading = false;
      _notify();
    }
  }

  Future<void> loadSchedules(DateTime date) async {
    final day = DateTime(date.year, date.month, date.day);
    final token = ++_scheduleRequest;
    scheduleDate = day;
    schedules = const [];
    loadingSchedules = true;
    scheduleError = null;
    _notify();
    try {
      final result = await repository.loadDay(userId: userId, date: day);
      if (_disposed || token != _scheduleRequest) return;
      DoctorWorkspaceController.validate(result, userId: userId, date: day);
      schedules = List.unmodifiable(result.schedules);
    } catch (_) {
      if (!_disposed && token == _scheduleRequest) {
        scheduleError = 'Không thể tải ca được phân công.';
      }
    }
    if (!_disposed && token == _scheduleRequest) {
      loadingSchedules = false;
      _notify();
    }
  }

  Future<bool> send(DoctorReportDraft draft) async {
    if (sending || !repository.canSubmitReports) return false;
    if (draft.reason.trim().isEmpty ||
        draft.reason.length > 200 ||
        draft.description.trim().isEmpty ||
        draft.description.length > 1000 ||
        !const [
          'Bận đột xuất',
          'Sự cố lịch làm',
          'Khác',
        ].contains(draft.type) ||
        !schedules.any(
          (schedule) =>
              schedule.id == draft.scheduleId &&
              schedule.workDate?.year == draft.date.year &&
              schedule.workDate?.month == draft.date.month &&
              schedule.workDate?.day == draft.date.day,
        )) {
      sendError = 'Vui lòng kiểm tra nội dung và chọn ca được phân công.';
      _notify();
      return false;
    }
    sending = true;
    sendError = null;
    _notify();
    try {
      final result = await repository.submitReport(
        userId: userId,
        draft: draft,
      );
      if (_disposed) return false;
      _historyRequest++;
      loading = false;
      error = null;
      reports = List.unmodifiable([
        result,
        ...reports.where((report) => report.id != result.id),
      ]);
      return true;
    } catch (_) {
      if (!_disposed) {
        sendError =
            'Gửi báo cáo thất bại. Nội dung được giữ lại để bạn thử lại.';
      }
      return false;
    } finally {
      sending = false;
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    reports = const [];
    schedules = const [];
    super.dispose();
  }
}
