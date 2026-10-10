import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:flutter_application_4/features/health_records/domain/entities/health_record.dart';
import 'package:flutter_application_4/features/health_records/domain/repositories/health_record_repository.dart';
import 'package:flutter_application_4/features/health_records/presentation/controllers/health_record_controller.dart';
import 'package:flutter_application_4/features/health_records/presentation/pages/health_records_page.dart';
import 'package:flutter_application_4/features/profile/domain/entities/patient.dart';
import 'package:flutter_application_4/features/profile/domain/repositories/patient_repository.dart';
import 'package:flutter_application_4/features/profile/presentation/controllers/patient_profile_controller.dart';

class _PatientRepository implements PatientRepository {
  _PatientRepository(this.patient);

  final Patient patient;

  @override
  Future<Patient> createPatient(Patient value) async => value;

  @override
  Future<Patient?> getPatientById(String patientId) async => patient;

  @override
  Future<Patient> updatePatient(Patient value) async => value;

  @override
  Stream<Patient?> watchPatientByAuthUser(String authUserId) =>
      Stream.value(patient);
}

class _HealthRecordRepository implements HealthRecordRepository {
  _HealthRecordRepository({this.records = const [], this.error});

  final List<HealthRecord> records;
  final Object? error;

  @override
  Future<List<HealthRecord>> getHealthRecordsByPatient(String patientId) async {
    if (error != null) throw error!;
    return records;
  }
}

void main() {
  const patient = Patient(
    id: 'patient-1',
    authUserId: 'auth-1',
    fullName: 'Nguyễn Minh An',
    phone: '0900000000',
    email: 'an@example.com',
    isActive: true,
  );

  Future<void> openPage(
    WidgetTester tester,
    HealthRecordRepository healthRecordRepository,
  ) async {
    final profileController = PatientProfileController(
      _PatientRepository(patient),
    );
    await profileController.loadPatient(patient.id);
    final healthRecordController = HealthRecordController(
      healthRecordRepository,
    );
    addTearDown(profileController.dispose);
    addTearDown(healthRecordController.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: profileController),
          ChangeNotifierProvider.value(value: healthRecordController),
        ],
        child: const MaterialApp(home: HealthRecordsPage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('displays Health Record test data for the signed-in patient', (
    tester,
  ) async {
    await openPage(
      tester,
      _HealthRecordRepository(
        records: [
          HealthRecord(
            id: 'record-1',
            patientId: patient.id,
            doctorId: 'doctor-1',
            recordDate: DateTime(2026, 10, 9, 9, 30),
            diagnosis: 'Tăng huyết áp cần theo dõi',
            prescription: 'Amlodipine 5mg',
            notes: 'Tái khám sau 30 ngày',
          ),
        ],
      ),
    );

    expect(find.text('09/10/2026 09:30'), findsOneWidget);
    expect(find.text('Chẩn đoán: Tăng huyết áp cần theo dõi'), findsOneWidget);
    expect(find.text('Đơn thuốc: Amlodipine 5mg'), findsOneWidget);
    expect(find.text('Ghi chú: Tái khám sau 30 ngày'), findsOneWidget);
  });

  testWidgets('displays the Health Record empty state when no records exist', (
    tester,
  ) async {
    await openPage(tester, _HealthRecordRepository());

    expect(find.text('Chưa có hồ sơ sức khỏe nào.'), findsOneWidget);
  });

  testWidgets('displays an error and allows retry when Health Record fails', (
    tester,
  ) async {
    await openPage(
      tester,
      _HealthRecordRepository(
        error: Exception('Không thể tải dữ liệu sức khỏe'),
      ),
    );

    expect(find.text('Không thể tải dữ liệu sức khỏe'), findsOneWidget);
    expect(find.text('Thử lại'), findsOneWidget);
  });
}
