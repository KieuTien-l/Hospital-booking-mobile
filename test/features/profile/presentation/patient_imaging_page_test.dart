import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application_4/core/themes/app_theme.dart';
import 'package:flutter_application_4/features/profile/domain/entities/patient.dart';
import 'package:flutter_application_4/features/profile/presentation/models/patient_profiles_demo_data.dart';
import 'package:flutter_application_4/features/profile/presentation/pages/patient_imaging_page.dart';
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
  testWidgets(
    'Imaging filters use selected patient, synchronize types and change year',
    (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: PatientImagingPage(
            patient: PatientProfilesDemoData.profiles[1],
            initialDate: DateTime(2026, 10, 10),
          ),
        ),
      );
      expect(find.text('Hình ảnh chụp (PACS)'), findsOneWidget);
      expect(find.text('NGUYỄN MINH ANH (DEMO-BN002)'), findsOneWidget);
      expect(find.byType(ChoiceChip), findsNWidgets(3));
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'X Quang'))
            .selected,
        isTrue,
      );
      await tester.tap(find.text('Chọn loại'));
      await tester.pumpAndSettle();
      for (final type in ['X Quang', 'CT Scan', 'MRI']) {
        expect(find.widgetWithText(ListTile, type), findsOneWidget);
      }
      await tester.tap(find.widgetWithText(ListTile, 'MRI'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'MRI'))
            .selected,
        isTrue,
      );
      await tester.tap(find.byTooltip('Năm trước'));
      await tester.pumpAndSettle();
      expect(find.text('2025'), findsOneWidget);
      expect(find.text('Không có hình ảnh chụp!'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Imaging fits small screens with larger text', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.5)),
          child: child!,
        ),
        home: PatientImagingPage(
          patient: PatientProfilesDemoData.profiles.first,
        ),
      ),
    );
    await tester.tap(find.text('Chọn loại'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'CT Scan'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Không có hình ảnh chụp!'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'PACS loads the selected patient image result from Firebase data',
    (tester) async {
      const patient = Patient(
        id: 'patient-pacs',
        authUserId: 'auth-pacs',
        fullName: 'Nguyễn Minh An',
        phone: '',
        email: '',
        isActive: true,
      );
      final controller = TestResultController(
        _TestResultRepository(
          results: [
            TestResult(
              id: 'xray-1',
              patientId: patient.id,
              resultType: 'X Quang',
              testName: 'X Quang ngực thẳng',
              resultDescription: 'Nhu mô phổi thông khí tốt.',
              testDate: DateTime(2026, 10, 10, 9),
            ),
            TestResult(
              id: 'other-patient',
              patientId: 'patient-other',
              resultType: 'X Quang',
              testName: 'Không được hiển thị',
              resultDescription: '',
              testDate: DateTime(2026, 10, 10),
            ),
            TestResult(
              id: 'mri-1',
              patientId: patient.id,
              resultType: 'MRI',
              testName: 'MRI sọ não',
              resultDescription: 'Không ghi nhận tổn thương cấp.',
              testDate: DateTime(2026, 10, 9),
            ),
          ],
        ),
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: controller,
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: PatientImagingPage(
              patient: patient,
              initialDate: DateTime(2026, 10, 10),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(controller.patientId, patient.id);
      expect(find.text('X Quang ngực thẳng'), findsOneWidget);
      expect(find.text('Không được hiển thị'), findsNothing);
      await tester.tap(find.widgetWithText(ChoiceChip, 'MRI'));
      await tester.pumpAndSettle();
      expect(find.text('X Quang ngực thẳng'), findsNothing);
      expect(find.text('MRI sọ não'), findsOneWidget);
      await tester.tap(find.text('MRI sọ não'));
      await tester.pumpAndSettle();
      expect(find.text('Chi tiết kết quả'), findsOneWidget);
      expect(find.text('Không ghi nhận tổn thương cấp.'), findsOneWidget);
    },
  );

  testWidgets('PACS provides an error state and retry action', (tester) async {
    const patient = Patient(
      id: 'patient-pacs',
      authUserId: 'auth-pacs',
      fullName: 'Nguyễn Minh An',
      phone: '',
      email: '',
      isActive: true,
    );
    final controller = TestResultController(
      _TestResultRepository(error: Exception('Không thể tải PACS')),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: controller,
        child: MaterialApp(
          home: PatientImagingPage(
            patient: patient,
            initialDate: DateTime(2026, 10, 10),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Không thể tải PACS'), findsOneWidget);
    expect(find.text('Thử lại'), findsOneWidget);
  });
}
