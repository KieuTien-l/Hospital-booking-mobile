import '../../domain/entities/doctor_workspace.dart';
import '../../domain/repositories/doctor_workspace_repository.dart';

/// Safe release fallback when no doctor backend has been deployed.
///
/// Returning an explicit error is intentional: demo data in a production
/// doctor account can be mistaken for clinical data.
class UnconfiguredDoctorWorkspaceRepository
    implements DoctorWorkspaceRepository {
  const UnconfiguredDoctorWorkspaceRepository();

  static const _message =
      'Chưa cấu hình backend bác sĩ cho bản phát hành này. '
      'Vui lòng liên hệ quản trị viên.';

  @override
  bool get isDemo => false;

  @override
  bool get canSubmitReports => false;
  @override
  bool get canWriteClinicalRecords => false;

  Never _unavailable() => throw const DoctorWorkspaceAccessException(_message);

  @override
  Future<DoctorDayData> loadDay({
    required String userId,
    required DateTime date,
  }) async => _unavailable();

  @override
  Future<void> updatePersonalProfile({
    required String userId,
    required DoctorPersonalProfileDraft draft,
  }) async => _unavailable();

  @override
  Future<List<DoctorReport>> loadReports({required String userId}) async =>
      _unavailable();

  @override
  Future<DoctorReport> submitReport({
    required String userId,
    required DoctorReportDraft draft,
  }) async => _unavailable();

  @override
  Future<DoctorAppointmentCompletion> completeAppointment({
    required String userId,
    required String appointmentId,
    required String requestId,
  }) async => _unavailable();

  @override
  Future<DoctorAppointmentCompletion> startExamination({
    required String userId,
    required String appointmentId,
    required String requestId,
  }) async => _unavailable();

  @override
  Future<DoctorAppointmentCompletion> markExaminationAwaitingResults({
    required String userId,
    required String appointmentId,
    required String requestId,
  }) async => _unavailable();

  @override
  Future<DoctorClinicalSaveResult> saveHealthRecord({
    required String userId,
    required DoctorHealthRecordDraft draft,
  }) async => _unavailable();

  @override
  Future<DoctorClinicalSaveResult> saveTestResult({
    required String userId,
    required DoctorTestResultDraft draft,
  }) async => _unavailable();
  @override
  Future<DoctorClinicalSaveResult> createClinicalOrder({
    required String userId,
    required DoctorClinicalOrderDraft draft,
  }) async => _unavailable();
  @override
  Future<List<DoctorClinicalOrderSummary>> loadClinicalOrders({
    required String userId,
    required String appointmentId,
  }) async => _unavailable();

  @override
  Future<List<DoctorHealthRecordSummary>> loadHealthRecords({
    required String userId,
    required String appointmentId,
  }) async => _unavailable();

  @override
  Future<List<DoctorTestResultSummary>> loadTestResults({
    required String userId,
    required String appointmentId,
  }) async => _unavailable();

  @override
  Future<DoctorPatientHistory> loadPatientHistory({
    required String userId,
    required String patientId,
  }) async => _unavailable();
}
