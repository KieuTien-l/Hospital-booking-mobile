import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_4/core/themes/app_theme.dart';
import 'package:flutter_application_4/features/profile/presentation/models/patient_profiles_demo_data.dart';
import 'package:flutter_application_4/features/profile/presentation/pages/patient_booking_history_page.dart';

void main() {
  Future<void> open(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: PatientBookingHistoryPage(
        patient: PatientProfilesDemoData.profiles.first,
        initialDate: DateTime(2026, 10, 10),
      ),
    ),
  );

  testWidgets('Statuses switch and empty history remains visible', (
    tester,
  ) async {
    await open(tester);
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Đã thanh toán'))
          .selected,
      isTrue,
    );
    for (final status in ['Đã tiếp nhận', 'Đã khám', 'Đã hủy']) {
      await tester.ensureVisible(find.text(status));
      await tester.tap(find.text(status));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, status))
            .selected,
        isTrue,
      );
      expect(find.text('Không có dữ liệu'), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('Filters commit only on Apply and Reset removes date range', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.text('Lọc'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Từ ngày'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<DatePickerDialog>(find.byType(DatePickerDialog)).lastDate,
      DateTime(2026, 10, 10),
    );
    await tester.tap(find.text('1'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Áp dụng'));
    await tester.pumpAndSettle();
    expect(find.text('01/10/2025 – 10/10/2026'), findsOneWidget);
    await tester.tap(find.text('Lọc'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đặt lại'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Đóng'));
    await tester.pumpAndSettle();
    expect(find.text('01/10/2025 – 10/10/2026'), findsOneWidget);
    await tester.tap(find.text('Lọc'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đặt lại'));
    await tester.tap(find.text('Áp dụng'));
    await tester.pumpAndSettle();
    expect(find.text('01/10/2025 – 10/10/2026'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Small screen with larger text supports filter sheet', (
    tester,
  ) async {
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
        home: PatientBookingHistoryPage(
          patient: PatientProfilesDemoData.profiles.first,
        ),
      ),
    );
    await tester.tap(find.text('Lọc'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Áp dụng'));
    await tester.tap(find.text('Áp dụng'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
