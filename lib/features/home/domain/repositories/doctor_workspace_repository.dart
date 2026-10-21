import '../entities/doctor_workspace.dart';

class DoctorWorkspaceAccessException implements Exception {
  const DoctorWorkspaceAccessException(this.message);
  final String message;
  @override String toString() => message;
}

/// Implementations must authorize every request using the signed-in account.
abstract interface class DoctorWorkspaceRepository {
  bool get isDemo;
  bool get canSubmitReports;
  Future<DoctorDayData> loadDay({
    required String userId,
    required DateTime date,
  });
  Future<List<DoctorReport>> loadReports({required String userId});
  Future<DoctorReport> submitReport({
    required String userId,
    required DoctorReportDraft draft,
  });
}
