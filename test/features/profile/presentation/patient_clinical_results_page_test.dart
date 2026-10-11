import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:flutter_application_4/features/profile/domain/entities/patient.dart';
import 'package:flutter_application_4/features/profile/presentation/pages/patient_clinical_results_page.dart';
import 'package:flutter_application_4/features/results/domain/entities/test_result.dart';
import 'package:flutter_application_4/features/results/domain/repositories/test_result_repository.dart';
import 'package:flutter_application_4/features/results/presentation/controllers/test_result_controller.dart';

class _TestResultRepository implements TestResultRepository {
  _TestResultRepository({this.results = const [], this.error});

  final List<TestResult> results;
  final Object? error;

  @override
  Future<List<TestResult>> getTestResultsByPatient(String patientId) async {
    if (error != null) throw error!;
    return results.where((result) => result.patientId == patientId).toList();
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
    TestResultRepository repository,
  ) async {
    final controller = TestResultController(repository);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: controller,
        child: MaterialApp(
          home: PatientClinicalResultsPage(
            patient: patient,
            initialDate: DateTime(2026, 10, 10),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows test data for the selected patient and opens detail', (
    tester,
  ) async {
    await openPage(
      tester,
      _TestResultRepository(
        results: [
          TestResult(
            id: 'result-1',
            patientId: patient.id,
            resultType: 'Xét nghiệm',
            testName: 'Công thức máu',
            resultDescription: 'Bạch cầu và hồng cầu trong giới hạn.',
            conclusion: 'Chưa ghi nhận bất thường.',
            referenceRange: 'Theo ngưỡng của phòng xét nghiệm.',
            doctorName: 'BS. Phạm Ngọc Mai',
            testDate: DateTime(2026, 10, 10, 9, 30),
          ),
        ],
      ),
    );

    expect(find.text('Công thức máu'), findsOneWidget);
    expect(find.text('10/10/2026'), findsOneWidget);
    await tester.tap(find.text('Công thức máu'));
    await tester.pumpAndSettle();
    expect(find.text('Chi tiết kết quả'), findsOneWidget);
    expect(find.text('Chưa ghi nhận bất thường.'), findsOneWidget);
    expect(find.text('BS. Phạm Ngọc Mai'), findsOneWidget);
  });

  testWidgets('shows the KieuTien empty state when there are no results', (
    tester,
  ) async {
    await openPage(tester, _TestResultRepository());

    expect(find.text('Không có kết quả!'), findsOneWidget);
    expect(find.text('Bạn chưa có kết quả cận lâm sàng nào.'), findsOneWidget);
  });

  testWidgets('shows an error and retry action when loading fails', (
    tester,
  ) async {
    await openPage(
      tester,
      _TestResultRepository(error: Exception('Không thể tải dữ liệu kết quả')),
    );

    expect(find.text('Không thể tải dữ liệu kết quả'), findsOneWidget);
    expect(find.text('Thử lại'), findsOneWidget);
  });

  testWidgets('filters live results by the selected KieuTien type', (
    tester,
  ) async {
    await openPage(
      tester,
      _TestResultRepository(
        results: [
          TestResult(
            id: 'lab',
            patientId: patient.id,
            resultType: 'Xét nghiệm',
            testName: 'Đường huyết',
            resultDescription: '5.1 mmol/L',
            testDate: DateTime(2026, 10, 10),
          ),
          TestResult(
            id: 'mri',
            patientId: patient.id,
            resultType: 'MRI',
            testName: 'MRI sọ não',
            resultDescription: 'Không ghi nhận tổn thương cấp.',
            testDate: DateTime(2026, 10, 9),
          ),
        ],
      ),
    );

    expect(find.text('Đường huyết'), findsOneWidget);
    expect(find.text('MRI sọ não'), findsNothing);
    await tester.tap(find.widgetWithText(ChoiceChip, 'MRI'));
    await tester.pumpAndSettle();
    expect(find.text('Đường huyết'), findsNothing);
    expect(find.text('MRI sọ não'), findsOneWidget);
  });
}
