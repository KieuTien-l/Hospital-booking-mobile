import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_4/core/themes/app_theme.dart';
import 'package:flutter_application_4/features/appointments/presentation/pages/select_appointment_time_page.dart';
import 'package:flutter_application_4/features/appointments/presentation/models/appointment_time_ui_models.dart';
import 'package:flutter_application_4/features/appointments/presentation/widgets/appointment_date_strip.dart';
import 'package:flutter_application_4/features/appointments/presentation/widgets/appointment_time_slot_grid.dart';
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
    Size size = const Size(412, 915),
    double scale = 1,
    List<AppointmentDoctorOption>? doctors,
    ValueChanged<AppointmentTimeSelection>? onContinue,
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
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: SelectAppointmentTimePage(
          specialty: specialty,
          initialDate: DateTime(2026, 10, 9),
          doctors: doctors,
          onContinue: onContinue,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> reveal(WidgetTester tester, Finder finder) async {
    final vertical = find
        .byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              widget.axisDirection == AxisDirection.down,
        )
        .first;
    if (finder.evaluate().isEmpty) {
      tester.state<ScrollableState>(vertical).position.jumpTo(0);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(finder, 180, scrollable: vertical);
    }
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
  }

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await reveal(tester, finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('Unavailable slots are disabled and continue returns selection', (
    tester,
  ) async {
    AppointmentTimeSelection? selection;
    await showPage(tester, onContinue: (value) => selection = value);
    await reveal(tester, find.byKey(const ValueKey('continue-time')));
    expect(
      tester
          .widget<ElevatedButton>(find.byKey(const ValueKey('continue-time')))
          .onPressed,
      isNull,
    );
    await reveal(tester, find.byKey(const ValueKey('slot-morning-1')));
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const ValueKey('slot-morning-1')))
          .onPressed,
      isNull,
    );
    await tapVisible(tester, find.byKey(const ValueKey('slot-morning-5')));
    await tapVisible(tester, find.byKey(const ValueKey('continue-time')));
    expect(selection!.doctor.id, 'demo-morning');
    expect(selection!.date, DateTime(2026, 10, 9));
    expect(selection!.slot.id, 'morning-5');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Only one global slot; changing date clears it and supports empty schedule',
    (tester) async {
      await showPage(tester);
      await tapVisible(tester, find.byKey(const ValueKey('slot-morning-5')));
      await tapVisible(
        tester,
        find.byKey(const ValueKey('expand-demo-afternoon')),
      );
      await tapVisible(tester, find.byKey(const ValueKey('slot-afternoon-1')));
      final grids = tester
          .widgetList<AppointmentTimeSlotGrid>(
            find.byType(AppointmentTimeSlotGrid),
          )
          .toList();
      expect(grids.where((grid) => grid.selectedId != null), hasLength(1));
      expect(grids.last.selectedId, 'afternoon-1');
      final strip = find.byType(AppointmentDateStrip).last;
      await tapVisible(
        tester,
        find.descendant(of: strip, matching: find.text('23/10')),
      );
      expect(
        tester
            .widget<ElevatedButton>(find.byKey(const ValueKey('continue-time')))
            .onPressed,
        isNull,
      );
      expect(
        find.text('Không có khung giờ khám trong ngày này.'),
        findsOneWidget,
      );
      expect(
        tester
            .widgetList<AppointmentDateStrip>(find.byType(AppointmentDateStrip))
            .every((strip) => strip.selected == DateTime(2026, 10, 23)),
        isTrue,
      );
      await tapVisible(
        tester,
        find.byKey(const ValueKey('expand-demo-afternoon')),
      );
      expect(find.byType(AppointmentTimeSlotGrid), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Empty doctors stays empty', (tester) async {
    await showPage(tester, doctors: []);
    expect(
      find.text('Chưa có bác sĩ và lịch khám để hiển thị.'),
      findsOneWidget,
    );
    expect(find.byType(AppointmentTimeSlotGrid), findsNothing);
    expect(
      tester
          .widget<ElevatedButton>(find.byKey(const ValueKey('continue-time')))
          .onPressed,
      isNull,
    );
  });

  for (final size in [const Size(412, 915), const Size(320, 700)]) {
    testWidgets('Layout and horizontal dates at $size with large text', (
      tester,
    ) async {
      await showPage(tester, size: size, scale: 1.5);
      await tapVisible(
        tester,
        find.byKey(const ValueKey('expand-demo-afternoon')),
      );
      final strip = find.byType(AppointmentDateStrip).last;
      await tester.ensureVisible(strip);
      await tester.drag(
        find.descendant(
          of: strip,
          matching: find.byType(SingleChildScrollView),
        ),
        const Offset(-350, 0),
      );
      await tester.pumpAndSettle();
      await reveal(tester, find.byKey(const ValueKey('continue-time')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
