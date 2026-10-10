import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_4/core/themes/app_theme.dart';
import 'package:flutter_application_4/features/profile/presentation/models/patient_profiles_demo_data.dart';
import 'package:flutter_application_4/features/profile/presentation/pages/patient_clinical_results_page.dart';

void main() {
  Future<void> open(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: PatientClinicalResultsPage(
        patient: PatientProfilesDemoData.profiles.first,
        initialDate: DateTime(2026, 10, 10),
      ),
    ),
  );

  testWidgets(
    'Six types synchronize sheet and chips and cancel preserves selection',
    (tester) async {
      await open(tester);
      expect(find.text('NGUYỄN VĂN AN (DEMO-BN001)'), findsOneWidget);
      expect(find.byType(ChoiceChip), findsNWidgets(6));
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Xét nghiệm'))
            .selected,
        isTrue,
      );
      await tester.tap(find.text('Chọn loại'));
      await tester.pumpAndSettle();
      for (final type in [
        'Xét nghiệm',
        'Siêu âm',
        'X Quang',
        'CT Scan',
        'MRI',
        'Nội soi',
      ]) {
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
      await tester.tap(find.widgetWithText(ChoiceChip, 'Nội soi'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chọn loại'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ListTile>(find.widgetWithText(ListTile, 'Nội soi'))
            .selected,
        isTrue,
      );
      await tester.tap(find.byTooltip('Đóng'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Nội soi'))
            .selected,
        isTrue,
      );
      expect(find.text('Không có kết quả!'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Year buttons enforce bounds and year dialog supports select and cancel',
    (tester) async {
      await open(tester);
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (widget) => widget is IconButton && widget.tooltip == 'Năm sau',
              ),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.byTooltip('Năm trước'));
      await tester.pump();
      expect(find.text('2025'), findsOneWidget);
      await tester.tap(find.byTooltip('Năm sau'));
      await tester.pump();
      await tester.tap(find.text('2026'));
      await tester.pumpAndSettle();
      final picker = tester.widget<YearPicker>(find.byType(YearPicker));
      expect(picker.firstDate.year, 1900);
      expect(picker.lastDate.year, 2026);
      await tester.tap(find.text('2024'));
      await tester.pumpAndSettle();
      expect(find.text('2024'), findsOneWidget);
      await tester.tap(find.text('2024'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();
      expect(find.text('2024'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Small screen and larger text do not overflow', (tester) async {
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
        home: PatientClinicalResultsPage(
          patient: PatientProfilesDemoData.profiles.first,
          initialDate: DateTime(2026, 10, 10),
        ),
      ),
    );
    await tester.tap(find.text('Chọn loại'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(ListTile, 'Nội soi'));
    await tester.tap(find.widgetWithText(ListTile, 'Nội soi'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Không có kết quả!'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
