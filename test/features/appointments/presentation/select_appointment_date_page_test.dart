import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_4/core/themes/app_theme.dart';
import 'package:flutter_application_4/features/appointments/presentation/models/appointment_calendar_demo_data.dart';
import 'package:flutter_application_4/features/appointments/presentation/pages/select_appointment_date_page.dart';
import 'package:flutter_application_4/features/appointments/presentation/widgets/appointment_calendar_legend.dart';
import 'package:flutter_application_4/features/appointments/presentation/widgets/appointment_calendar_day.dart';
import 'package:flutter_application_4/features/specialties/domain/entities/specialty.dart';

const specialty = Specialty(
  id: 'skin',
  name: 'Da liễu',
  description: '',
  isActive: true,
);

void main() {
  Future<void> showPage(
    WidgetTester tester, {
    DateTime? today,
    Set<DateTime>? available,
    Set<DateTime>? holidays,
    ValueChanged<DateTime?>? onSelected,
    Size size = const Size(412, 915),
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: SelectAppointmentDatePage(
          specialty: specialty,
          onHome: () {},
          today: today,
          availableDates: available,
          holidayDates: holidays,
          onDateSelected: onSelected,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Starts in current month and marks today without changing availability',
    (tester) async {
      await showPage(tester);
      final now = DateTime.now();
      expect(find.text('Tháng ${now.month} - ${now.year}'), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (widget) =>
                    widget is IconButton && widget.tooltip == 'Tháng trước',
              ),
            )
            .onPressed,
        isNull,
      );
      final today = tester.widget<AppointmentCalendarDay>(
        find.byKey(ValueKey(DateUtils.dateOnly(now))),
      );
      expect(today.isToday, isTrue);
      expect(
        today.isAvailable,
        AppointmentCalendarDemoData.availableDates(now)
            .contains(DateUtils.dateOnly(now)),
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final entry in [
    (2027, 2, 28),
    (2028, 2, 29),
    (2026, 4, 30),
    (2026, 10, 31),
  ]) {
    testWidgets(
      'Correct day count and weekday columns for ${entry.$1}/${entry.$2}',
      (tester) async {
        final first = DateTime(entry.$1, entry.$2);
        await showPage(tester, today: first);
        expect(find.byType(AppointmentCalendarDay), findsNWidgets(entry.$3));
        final firstRect = tester.getRect(find.byKey(ValueKey(first)));
        final grid = tester.getRect(find.byType(GridView));
        final cellWidth = (grid.width - 36) / 7;
        expect(
          firstRect.left - grid.left,
          closeTo((first.weekday % 7) * (cellWidth + 6), .1),
        );
        final last = tester.widget<AppointmentCalendarDay>(
          find.byKey(ValueKey(DateTime(entry.$1, entry.$2, entry.$3))),
        );
        expect(last.date.day, entry.$3);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('Month navigation crosses year and stops at current month', (
    tester,
  ) async {
    await showPage(tester, today: DateTime(2026, 12, 8));
    await tester.tap(find.byTooltip('Tháng sau'));
    await tester.pumpAndSettle();
    expect(find.text('Tháng 1 - 2027'), findsOneWidget);
    await tester.tap(find.byTooltip('Tháng trước'));
    await tester.pumpAndSettle();
    expect(find.text('Tháng 12 - 2026'), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(
            find.byWidgetPredicate(
              (widget) =>
                  widget is IconButton && widget.tooltip == 'Tháng trước',
            ),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets(
    'Past and unavailable dates are locked; today and holidays remain selectable',
    (tester) async {
      DateTime? selected;
      final today = DateTime(2026, 10, 8);
      await showPage(
        tester,
        today: today,
        available: {
          DateTime(2026, 10, 7),
          DateTime(2026, 10, 8, 13),
          DateTime(2026, 10, 9),
        },
        holidays: {DateTime(2026, 10, 9, 15)},
        onSelected: (value) => selected = value,
      );
      AppointmentCalendarDay cell(int day) =>
          tester.widget(find.byKey(ValueKey(DateTime(2026, 10, day))));
      expect(cell(7).isAvailable, isFalse);
      expect(cell(10).isAvailable, isFalse);
      await tester.tap(find.byKey(ValueKey(DateTime(2026, 10, 7))));
      expect(selected, isNull);
      await tester.tap(find.byKey(ValueKey(today)));
      await tester.pump();
      expect(selected, today);
      expect(cell(8).isSelected, isTrue);
      await tester.tap(find.byKey(ValueKey(DateTime(2026, 10, 9))));
      await tester.pump();
      expect(cell(8).isSelected, isFalse);
      expect(cell(9).isSelected, isTrue);
      expect(cell(9).isHoliday, isTrue);
      expect(find.text('Ngày đã chọn: 09/10/2026'), findsOneWidget);
      expect(
        tester
            .widgetList<AppointmentCalendarDay>(
              find.byType(AppointmentCalendarDay),
            )
            .where((day) => day.isSelected),
        hasLength(1),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Empty availability stays empty and disabled today keeps its marker',
    (tester) async {
      await showPage(tester, today: DateTime(2026, 10, 8), available: {});
      final days = tester.widgetList<AppointmentCalendarDay>(
        find.byType(AppointmentCalendarDay),
      );
      expect(days.every((day) => !day.isAvailable), isTrue);
      expect(days.singleWhere((day) => day.isToday).date.day, 8);
      expect(find.textContaining('Lịch minh họa'), findsNothing);
    },
  );

  testWidgets('Data updates clear a date that is no longer available', (
    tester,
  ) async {
    DateTime? selected;
    final today = DateTime(2026, 10, 8);
    final dates = {today};
    await showPage(
      tester,
      today: today,
      available: dates,
      onSelected: (value) => selected = value,
    );
    await tester.tap(find.byKey(ValueKey(today)));
    await tester.pump();
    expect(selected, today);
    dates.clear();
    await showPage(
      tester,
      today: today,
      available: dates,
      onSelected: (value) => selected = value,
    );
    expect(selected, isNull);
    expect(find.textContaining('Ngày đã chọn:'), findsNothing);
  });

  testWidgets('Small screen with enlarged text has no overflow', (
    tester,
  ) async {
    await showPage(
      tester,
      today: DateTime(2026, 8, 8),
      size: const Size(320, 700),
      textScale: 1.5,
    );
    await tester.ensureVisible(find.byType(AppointmentCalendarLegend));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
