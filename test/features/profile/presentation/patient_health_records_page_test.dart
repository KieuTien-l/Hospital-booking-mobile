import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_4/core/themes/app_theme.dart';
import 'package:flutter_application_4/features/profile/domain/entities/patient.dart';
import 'package:flutter_application_4/features/profile/presentation/models/patient_profiles_demo_data.dart';
import 'package:flutter_application_4/features/profile/presentation/pages/patient_health_records_page.dart';
import 'package:flutter_application_4/features/profile/presentation/widgets/health_records_date_filter.dart';

void main() {
  Future<void> open(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: PatientHealthRecordsPage(
        patient: PatientProfilesDemoData.profiles.first,
        initialDate: DateTime(2026, 10, 10),
      ),
    ),
  );

  testWidgets('Tabs change guidance and preserve outpatient category', (
    tester,
  ) async {
    await open(tester);
    expect(find.text('NGUYỄN VĂN AN'), findsOneWidget);
    expect(find.text('(DEMO-BN001)'), findsOneWidget);
    expect(find.text('10/10/2025'), findsOneWidget);
    expect(find.text('10/10/2026'), findsOneWidget);
    await tester.tap(find.text('Phiếu chỉ định'));
    await tester.pump();
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Phiếu chỉ định'))
          .selected,
      isTrue,
    );
    await tester.tap(find.text('Nhập viện'));
    await tester.pump();
    expect(find.byType(ChoiceChip), findsNothing);
    expect(
      find.text('Vui lòng thử điều chỉnh bộ lọc ngày để xem kết quả.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Khám sức khỏe'));
    await tester.pump();
    expect(
      find.text(
        'Vui lòng thử điều chỉnh bộ lọc ngày để xem kết quả khám sức khỏe.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Khám bệnh'));
    await tester.pump();
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Phiếu chỉ định'))
          .selected,
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Date pickers constrain range, update dates and allow cancel', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.text('Từ ngày'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<DatePickerDialog>(find.byType(DatePickerDialog)).lastDate,
      DateTime(2026, 10, 10),
    );
    await tester.tap(find.text('1'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('01/10/2025'), findsOneWidget);
    await tester.tap(find.text('Đến ngày'));
    await tester.pumpAndSettle();
    final picker = tester.widget<DatePickerDialog>(
      find.byType(DatePickerDialog),
    );
    expect(picker.firstDate, DateTime(2025, 10, 1));
    expect(picker.lastDate, DateTime(2026, 10, 10));
    await tester.tap(find.text('1'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('01/10/2026'), findsOneWidget);
    await tester.tap(find.text('Từ ngày'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<DatePickerDialog>(find.byType(DatePickerDialog)).lastDate,
      DateTime(2026, 10, 1),
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('01/10/2025'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Small screen and larger text can scroll without overflow', (
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
        home: PatientHealthRecordsPage(
          patient: const Patient(
            id: 'DEMO-LONG',
            authUserId: 'demo',
            fullName: 'Nguyễn Thị Hoàng Minh Anh tên hồ sơ dài',
            phone: '',
            email: '',
            isActive: true,
          ),
          initialDate: DateTime(2024, 2, 29),
        ),
      ),
    );
    expect(find.text('28/02/2023'), findsOneWidget);
    expect(find.byType(HealthRecordsDateFilter), findsOneWidget);
    await tester.ensureVisible(find.text('Không có kết quả!'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
