import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_4/core/themes/app_theme.dart';
import 'package:flutter_application_4/features/profile/domain/entities/patient.dart';
import 'package:flutter_application_4/features/profile/presentation/models/patient_profiles_demo_data.dart';
import 'package:flutter_application_4/features/profile/presentation/pages/patient_clinical_profiles_page.dart';
import 'package:flutter_application_4/features/profile/presentation/pages/patient_clinical_results_page.dart';
import 'package:flutter_application_4/features/profile/presentation/pages/patient_imaging_page.dart';
import 'package:flutter_application_4/features/profile/presentation/widgets/patient_profile_card.dart';

void main() {
  testWidgets(
    'Selected profile reaches existing pages and back closes the sheet',
    (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const PatientClinicalProfilesPage(
            profiles: PatientProfilesDemoData.profiles,
            isDemo: true,
          ),
        ),
      );
      expect(find.byType(PatientProfileCard), findsNWidgets(3));
      expect(find.text('Liên kết hồ sơ'), findsNothing);
      expect(find.text('0910000678'), findsNothing);
      for (final imaging in [false, true]) {
        await tester.tap(find.text('NGUYỄN MINH ANH'));
        await tester.pumpAndSettle();
        expect(find.text('NGUYỄN MINH ANH • DEMO-BN002'), findsOneWidget);
        expect(find.text('HỒ SƠ SỨC KHỎE'), findsNothing);
        await tester.tap(
          find.text(imaging ? 'HÌNH ẢNH CHỤP (PACS)' : 'KẾT QUẢ CẬN LÂM SÀNG'),
        );
        await tester.pumpAndSettle();
        expect(find.text('Chọn chức năng'), findsNothing);
        if (imaging) {
          expect(
            tester
                .widget<PatientImagingPage>(find.byType(PatientImagingPage))
                .patient,
            same(PatientProfilesDemoData.profiles[1]),
          );
        } else {
          expect(
            tester
                .widget<PatientClinicalResultsPage>(
                  find.byType(PatientClinicalResultsPage),
                )
                .patient,
            same(PatientProfilesDemoData.profiles[1]),
          );
        }
        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(find.text('Chọn chức năng'), findsNothing);
        expect(find.byType(PatientProfileCard), findsNWidgets(3));
      }
      await tester.tap(find.text('NGUYỄN VĂN AN'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Đóng'));
      await tester.pumpAndSettle();
      expect(find.text('Chọn chức năng'), findsNothing);
      await tester.tap(find.text('NGUYỄN VĂN AN'));
      await tester.pumpAndSettle();
      await tester.drag(find.text('Chọn chức năng'), const Offset(0, 600));
      await tester.pumpAndSettle();
      expect(find.text('Chọn chức năng'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Empty profiles have no extra actions', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const PatientClinicalProfilesPage(profiles: []),
      ),
    );
    expect(find.text('Bạn chưa có hồ sơ người bệnh.'), findsOneWidget);
    expect(find.byType(PatientProfileCard), findsNothing);
    expect(find.text('Liên kết hồ sơ'), findsNothing);
  });

  testWidgets('Small screen and larger text keep sheet scrollable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const patient = Patient(
      id: 'DEMO-LONG',
      authUserId: 'demo-account',
      fullName: 'Nguyễn Thị Minh Anh tên hồ sơ rất dài để kiểm tra bố cục',
      phone: '0910000678',
      email: '',
      isActive: true,
      relationshipToAccountHolder: 'Tôi',
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.5)),
          child: child!,
        ),
        home: PatientClinicalProfilesPage(profiles: [patient]),
      ),
    );
    await tester.tap(find.byType(PatientProfileCard));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('HÌNH ẢNH CHỤP (PACS)'));
    expect(tester.takeException(), isNull);
  });
}
