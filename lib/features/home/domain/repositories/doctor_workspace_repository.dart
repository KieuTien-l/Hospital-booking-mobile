import '../entities/doctor_workspace.dart';

class DoctorPersonalProfileDraft {
  const DoctorPersonalProfileDraft({
    required this.fullName,
    required this.email,
    required this.phone,
    required this.dateOfBirth,
  });
  final String fullName, email, phone;
  final DateTime dateOfBirth;
}

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
  Future<void> updatePersonalProfile({
    required String userId,
    required DoctorPersonalProfileDraft draft,
  });
  Future<List<DoctorReport>> loadReports({required String userId});
  Future<DoctorReport> submitReport({
    required String userId,
    required DoctorReportDraft draft,
  });
  Future<DoctorAppointmentCompletion> completeAppointment({
    required String userId,
    required String appointmentId,
    required String requestId,
  });
  Future<DoctorAppointmentCompletion> startExamination({
    required String userId,
    required String appointmentId,
    required String requestId,
  }) => Future.error(
    const DoctorWorkspaceAccessException('Chưa hỗ trợ tạo phiếu khám.'),
  );
  Future<DoctorAppointmentCompletion> markExaminationAwaitingResults({
    required String userId,
    required String appointmentId,
    required String requestId,
  }) => Future.error(
    const DoctorWorkspaceAccessException(
      'Chưa hỗ trợ chuyển phiếu khám sang chờ kết quả CLS.',
    ),
  );
  Future<DoctorClinicalSaveResult> saveHealthRecord({
    required String userId,
    required DoctorHealthRecordDraft draft,
  });
  Future<DoctorClinicalSaveResult> saveTestResult({
    required String userId,
    required DoctorTestResultDraft draft,
  });
  Future<DoctorClinicalSaveResult> createClinicalOrder({
    required String userId,
    required DoctorClinicalOrderDraft draft,
  });
  Future<List<DoctorClinicalOrderSummary>> loadClinicalOrders({
    required String userId,
    required String appointmentId,
  });
  Future<List<DoctorHealthRecordSummary>> loadHealthRecords({
    required String userId,
    required String appointmentId,
  });
  Future<List<DoctorTestResultSummary>> loadTestResults({
    required String userId,
    required String appointmentId,
  });
  Future<DoctorPatientHistory> loadPatientHistory({
    required String userId,
    required String patientId,
  });
}
