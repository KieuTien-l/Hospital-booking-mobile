import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_4/core/state/view_state.dart';
import 'package:flutter_application_4/core/themes/app_theme.dart';
import 'package:flutter_application_4/features/appointments/domain/entities/appointment.dart';
import 'package:flutter_application_4/features/appointments/presentation/models/appointment_history_demo_data.dart';
import 'package:flutter_application_4/features/appointments/presentation/models/appointment_history_ui_model.dart';
import 'package:flutter_application_4/features/appointments/presentation/pages/appointment_history_page.dart';
import 'package:flutter_application_4/features/appointments/presentation/widgets/appointment_history_card.dart';

void main() {
  testWidgets('Demo cards fit small screens with larger text', (tester) async {
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
        home: AppointmentHistoryPage(
          items: AppointmentHistoryDemoData.items,
          isDemo: true,
        ),
      ),
    );
    await tester.ensureVisible(find.text('Khung giờ: 08:30 – 09:30'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Lọc'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Áp dụng'));
    await tester.tap(find.text('Áp dụng'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  Future<void> open(
    WidgetTester tester, {
    ViewState state = ViewState.success,
    VoidCallback? retry,
  }) => tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: AppointmentHistoryPage(
        items: AppointmentHistoryDemoData.items,
        isDemo: true,
        initialDate: DateTime(2026, 10, 10),
        viewState: state,
        onRetry: retry,
      ),
    ),
  );

  test('Business statuses keep their values and unsupported values are not relabeled', () {
    for (final status in [
      AppointmentStatus.pending,
      AppointmentStatus.noShow,
      AppointmentStatus.unknown,
    ]) {
      final item = AppointmentHistoryUiModel(
        appointment: Appointment(
          id: 'a',
          patientId: 'p',
          doctorId: 'd',
          workScheduleId: 'w',
          timeSlotId: 't',
          status: status,
        ),
        patientName: '',
        doctorName: '',
        specialtyName: '',
      );
      expect(item.tab, isNull);
      expect(item.appointment.status, status);
    }
    expect(
      AppointmentHistoryDemoData.items.first.tab,
      AppointmentHistoryTab.paid,
    );
  });

  testWidgets('Tabs filter demo cards and tap does not enter booking flow', (
    tester,
  ) async {
    await open(tester);
    for (var i = 0; i < AppointmentHistoryTab.values.length; i++) {
      final tab = AppointmentHistoryTab.values[i];
      await tester.ensureVisible(find.widgetWithText(ChoiceChip, tab.label));
      await tester.tap(find.widgetWithText(ChoiceChip, tab.label));
      await tester.pumpAndSettle();
      expect(find.byType(AppointmentHistoryCard), findsOneWidget);
      expect(find.text('DEMO-AP00${i + 1}'), findsOneWidget);
    }
    await tester.tap(find.text('DEMO-AP004'));
    await tester.pumpAndSettle();
    expect(
      find.text('Chức năng xem chi tiết lịch khám đang được hoàn thiện.'),
      findsOneWidget,
    );
    expect(find.text('Chọn hồ sơ'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Date and specialty filters combine with tab, cancel and reset work',
    (tester) async {
      await open(tester);
      await tester.tap(find.text('Lọc'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Đến ngày'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<DatePickerDialog>(find.byType(DatePickerDialog))
            .lastDate
            .year,
        2036,
      );
      await tester.tap(find.text('15'));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Áp dụng'));
      await tester.pumpAndSettle();
      expect(find.text('DEMO-AP001'), findsOneWidget);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Đã tiếp nhận'));
      await tester.pumpAndSettle();
      expect(find.text('Không có dữ liệu'), findsOneWidget);
      await tester.tap(find.text('Lọc'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Đặt lại'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Đóng'));
      await tester.pumpAndSettle();
      expect(find.text('Không có dữ liệu'), findsOneWidget);
      await tester.tap(find.text('Lọc'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Đặt lại'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tất cả chuyên khoa'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nội tổng quát').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Áp dụng'));
      await tester.pumpAndSettle();
      expect(find.text('Không có dữ liệu'), findsOneWidget);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Đã thanh toán'));
      await tester.pumpAndSettle();
      expect(find.text('DEMO-AP001'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Loading error retry and profile-scoped empty UI are externally controlled',
    (tester) async {
      await open(tester, state: ViewState.loading);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      var retried = false;
      await open(tester, state: ViewState.error, retry: () => retried = true);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Thử lại'));
      expect(retried, isTrue);
      await tester.pumpWidget(
        MaterialApp(
          home: AppointmentHistoryPage(
            items: AppointmentHistoryDemoData.items,
            patientId: 'other',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Không có dữ liệu'), findsOneWidget);
      expect(find.byType(AppointmentHistoryCard), findsNothing);
    },
  );
}
