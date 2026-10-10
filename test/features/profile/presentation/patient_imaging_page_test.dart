import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_4/core/themes/app_theme.dart';
import 'package:flutter_application_4/features/profile/presentation/models/patient_profiles_demo_data.dart';
import 'package:flutter_application_4/features/profile/presentation/pages/patient_imaging_page.dart';

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
}
