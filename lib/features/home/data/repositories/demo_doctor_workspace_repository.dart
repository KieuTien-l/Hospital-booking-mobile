import '../../../doctors/domain/entities/doctor.dart';
import '../../domain/entities/doctor_workspace.dart';
import '../../domain/repositories/doctor_workspace_repository.dart';
import '../fixtures/doctor_home_demo_data.dart';

class DemoDoctorWorkspaceRepository implements DoctorWorkspaceRepository {
  const DemoDoctorWorkspaceRepository();
  @override
  bool get isDemo => true;
  @override
  bool get canSubmitReports => false;
  @override
  bool get canWriteClinicalRecords => false;
  @override
  Future<DoctorDayData> loadDay({
    required String userId,
    required DateTime date,
  }) async {
    final schedules = DoctorHomeDemoData.schedules(
      DateTime.now(),
      selectedDate: date,
    ).where((schedule) => schedule.workDate == date).toList();
    return DoctorDayData(
      doctor: Doctor(
        id: 'demo-doctor',
        userId: userId,
        fullName: '',
        email: '',
        phone: '',
        specialtyId: '',
        yearsOfExperience: 0,
        consultationFee: 0,
        isActive: true,
      ),
      date: date,
      schedules: schedules,
      slots: DoctorHomeDemoData.timeSlots(schedules),
      bookings: DoctorHomeDemoData.bookings(schedules),
    );
  }

  @override
  Future<List<DoctorReport>> loadReports({required String userId}) async =>
      const [];
  @override
  Future<DoctorReport> submitReport({
    required String userId,
    required DoctorReportDraft draft,
  }) => Future.error(StateError('Chế độ mẫu không gửi báo cáo.'));
  @override
  Future<DoctorClinicalSaveResult> saveHealthRecord({
    required String userId,
    required DoctorHealthRecordDraft draft,
  }) => Future.error(StateError('Chế độ mẫu không lưu hồ sơ y tế.'));
  @override
  Future<DoctorClinicalSaveResult> saveTestResult({
    required String userId,
    required DoctorTestResultDraft draft,
  }) => Future.error(StateError('Chế độ mẫu không lưu kết quả CLS.'));
  @override
  Future<List<DoctorHealthRecordSummary>> loadHealthRecords({
    required String userId,
    required String appointmentId,
  }) async => const [];
  @override
  Future<List<DoctorTestResultSummary>> loadTestResults({
    required String userId,
    required String appointmentId,
  }) async => const [];
}
