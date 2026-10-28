import '../entities/doctor_workspace.dart';

class DoctorWorkspaceAccessException implements Exception {
  const DoctorWorkspaceAccessException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Implementations must authorize every request using the signed-in account.
abstract interface class DoctorWorkspaceRepository {
  bool get isDemo;
  bool get canSubmitReports;
  bool get canWriteClinicalRecords;
  Future<DoctorDayData> loadDay({
    required String userId,
    required DateTime date,
  });
  Future<List<DoctorReport>> loadReports({required String userId});
  Future<DoctorReport> submitReport({
    required String userId,
    required DoctorReportDraft draft,
  });
  Future<DoctorClinicalSaveResult> saveHealthRecord({
    required String userId,
    required DoctorHealthRecordDraft draft,
  });
  Future<DoctorClinicalSaveResult> saveTestResult({
    required String userId,
    required DoctorTestResultDraft draft,
  });
  Future<List<DoctorHealthRecordSummary>> loadHealthRecords({
    required String userId,
    required String appointmentId,
  });
  Future<List<DoctorTestResultSummary>> loadTestResults({
    required String userId,
    required String appointmentId,
  });
}
