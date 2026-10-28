import 'dart:async';

import 'package:flutter_application_4/features/auth/domain/entities/user_entity.dart';
import 'package:flutter_application_4/features/auth/domain/repositories/auth_repository.dart';
import 'package:flutter_application_4/features/doctors/domain/entities/doctor.dart';
import 'package:flutter_application_4/features/home/domain/entities/doctor_workspace.dart';
import 'package:flutter_application_4/features/home/domain/repositories/doctor_workspace_repository.dart';
import 'package:flutter_application_4/features/home/presentation/models/doctor_home_demo_data.dart';

UserEntity testDoctor({
  String id = 'account',
  String email = 'old@example.test',
}) => UserEntity(
  id: id,
  email: email,
  fullName: 'Bác sĩ kiểm thử',
  phone: '0900000000',
  role: UserRole.doctor,
  isActive: true,
);

class TestAuthRepository implements AuthRepository {
  UserEntity? user = testDoctor();
  final events = StreamController<String?>.broadcast();
  @override
  Stream<String?> get authStateChanges => events.stream;
  @override
  Future<UserEntity?> getCurrentUser() async => user;
  @override
  Future<UserRole?> getUserRole() async => user?.role;
  @override
  Future<void> logout() async {
    user = null;
    events.add(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

DoctorDayData testDay(DateTime date, {String userId = 'account'}) {
  final schedules = DoctorHomeDemoData.schedules(
    DateTime(2026, 10, 16),
    selectedDate: date,
  ).where((schedule) => schedule.workDate == date).toList();
  return DoctorDayData(
    doctor: Doctor(
      id: 'demo-doctor',
      userId: userId,
      fullName: 'Bác sĩ kiểm thử',
      email: '',
      phone: '',
      specialtyId: 'noi',
      specialtyName: 'Nội tổng quát',
      qualification: 'Thạc sĩ',
      yearsOfExperience: 10,
      consultationFee: 100000,
      isActive: true,
    ),
    date: date,
    schedules: schedules,
    slots: DoctorHomeDemoData.timeSlots(schedules),
    bookings: DoctorHomeDemoData.bookings(schedules),
  );
}

class TestWorkspaceRepository implements DoctorWorkspaceRepository {
  @override
  bool get isDemo => false;
  @override
  bool get canSubmitReports => true;
  @override
  bool get canWriteClinicalRecords => true;
  Future<DoctorDayData> Function(DateTime date)? dayLoader;
  Future<List<DoctorReport>> Function()? historyLoader;
  Future<DoctorReport> Function(DoctorReportDraft draft)? sender;
  int dayCalls = 0, sendCalls = 0;
  @override
  Future<DoctorDayData> loadDay({
    required String userId,
    required DateTime date,
  }) {
    dayCalls++;
    return dayLoader?.call(date) ?? Future.value(testDay(date, userId: userId));
  }

  @override
  Future<List<DoctorReport>> loadReports({required String userId}) =>
      historyLoader?.call() ?? Future.value([]);
  @override
  Future<DoctorReport> submitReport({
    required String userId,
    required DoctorReportDraft draft,
  }) {
    sendCalls++;
    return sender?.call(draft) ??
        Future.value(
          DoctorReport(
            id: draft.requestId,
            type: draft.type,
            date: draft.date,
            reason: draft.reason,
            status: DoctorReportStatus.pending,
          ),
        );
  }

  @override
  Future<DoctorClinicalSaveResult> saveHealthRecord({
    required String userId,
    required DoctorHealthRecordDraft draft,
  }) async => DoctorClinicalSaveResult(
    id: draft.id ?? draft.requestId,
    message: 'Đã tạo hồ sơ y tế.',
  );

  @override
  Future<DoctorClinicalSaveResult> saveTestResult({
    required String userId,
    required DoctorTestResultDraft draft,
  }) async => DoctorClinicalSaveResult(
    id: draft.id ?? draft.requestId,
    message: 'Đã tạo kết quả CLS.',
  );

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
