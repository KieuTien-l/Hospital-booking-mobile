import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_4/core/themes/app_theme.dart';
import 'package:flutter_application_4/features/appointments/domain/entities/appointment.dart';
import 'package:flutter_application_4/features/home/presentation/models/doctor_home_demo_data.dart';
import 'package:flutter_application_4/features/home/presentation/models/doctor_slot_booking.dart';
import 'package:flutter_application_4/features/home/presentation/pages/doctor_slot_details_page.dart';
import 'package:flutter_application_4/features/home/presentation/widgets/doctor_dashboard_stat_card.dart';

final _schedules = DoctorHomeDemoData.schedules(DateTime(2026, 10, 16));
final _schedule = _schedules.firstWhere(
  (schedule) => schedule.id == 'DEMO-2-SANG',
);
final _slots = DoctorHomeDemoData.timeSlots([_schedule]);
final _bookings = DoctorHomeDemoData.bookings(_schedules);

Future<void> _pump(
  WidgetTester tester, {
  int slotIndex = 0,
  List<DoctorSlotBooking>? bookings,
  bool connected = true,
  double scale = 1,
}) => tester.pumpWidget(
  RepaintBoundary(
    key: const ValueKey('slot-preview'),
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: DoctorSlotDetailsPage(
        schedule: _schedule,
        slot: _slots[slotIndex],
        bookings: connected ? bookings ?? _bookings : null,
        isDemo: connected,
      ),
    ),
  ),
);

List<int?> _totals(WidgetTester tester) => tester
    .widgetList<DoctorDashboardStatCard>(find.byType(DoctorDashboardStatCard))
    .map((card) => card.value)
    .toList();

void main() {
  testWidgets(
    'Only active bookings of the selected doctor, date, schedule and slot appear',
    (tester) async {
      DoctorSlotBooking other(
        String name, {
        String doctor = 'demo-doctor',
        String schedule = 'DEMO-2-SANG',
        String slot = 'DEMO-2-SANG-SLOT-0',
        DateTime? date,
        AppointmentStatus status = AppointmentStatus.confirmed,
      }) => DoctorSlotBooking(
        patientName: name,
        appointment: Appointment(
          id: name,
          patientId: name,
          doctorId: doctor,
          workScheduleId: schedule,
          timeSlotId: slot,
          appointmentDate: date ?? DateTime(2026, 10, 16),
          status: status,
        ),
      );
      final invalid = [
        other('Other doctor', doctor: 'other'),
        other('Other schedule', schedule: 'other'),
        other('Other slot', slot: 'other'),
        other('Other date', date: DateTime(2026, 10, 17)),
        other('Cancelled booking', status: AppointmentStatus.cancelled),
      ];
      await _pump(tester, bookings: [..._bookings.reversed, ...invalid]);
      expect(find.text('06:30 - 07:30'), findsOneWidget);
      expect(find.text('Đã đặt: 3 / 3 chỗ'), findsOneWidget);
      expect(find.text('Nguyễn Minh Anh'), findsOneWidget);
      expect(find.text('Trần Quốc Bảo'), findsOneWidget);
      expect(find.text('Lê Hoàng Phúc'), findsOneWidget);
      expect(find.text('Phạm Ngọc Mai'), findsNothing);
      for (final booking in invalid) {
        expect(find.text(booking.patientName), findsNothing);
      }
      expect(_totals(tester), [3, 3, 0]);
      final names = ['Nguyễn Minh Anh', 'Trần Quốc Bảo', 'Lê Hoàng Phúc'];
      expect(
        tester.getTopLeft(find.text(names[0])).dy,
        lessThan(tester.getTopLeft(find.text(names[1])).dy),
      );
      expect(
        tester.getTopLeft(find.text(names[1])).dy,
        lessThan(tester.getTopLeft(find.text(names[2])).dy),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Status and name or patient code filters preserve slot totals', (
    tester,
  ) async {
    await _pump(tester, slotIndex: 2);
    expect(_totals(tester), [3, 1, 2]);
    final waiting = find.widgetWithText(ChoiceChip, 'Chờ khám');
    await tester.ensureVisible(waiting);
    await tester.tap(waiting);
    await tester.pumpAndSettle();
    expect(find.text('Bùi Gia Huy'), findsNothing);
    expect(find.text('Đỗ Khánh Linh'), findsOneWidget);
    expect(find.text('Nguyễn Minh Anh'), findsOneWidget);
    final search = find.byKey(const ValueKey('doctor-booking-search'));
    await tester.ensureVisible(search);
    await tester.enterText(search, 'DEMO-BN-8');
    await tester.pumpAndSettle();
    expect(find.text('Đỗ Khánh Linh'), findsOneWidget);
    expect(find.text('Nguyễn Minh Anh'), findsNothing);
    await tester.enterText(search, 'khánh linh');
    await tester.pumpAndSettle();
    expect(find.text('Đỗ Khánh Linh'), findsOneWidget);
    await tester.enterText(search, 'không tồn tại');
    await tester.pumpAndSettle();
    expect(find.text('Không tìm thấy bệnh nhân'), findsOneWidget);
    expect(_totals(tester), [3, 1, 2]);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'An open slot with no bookings shows an empty list, not other patients',
    (tester) async {
      await _pump(tester, slotIndex: 4);
      expect(find.text('Đã đặt: 0 / 3 chỗ'), findsOneWidget);
      expect(find.text('Chưa có bệnh nhân đặt ca này'), findsOneWidget);
      expect(find.text('Nguyễn Minh Anh'), findsNothing);
      expect(_totals(tester), [0, 0, 0]);
      expect(find.byType(TextField), findsNothing);
    },
  );

  testWidgets('An unconnected source keeps counts unavailable', (tester) async {
    await _pump(tester, connected: false);
    expect(find.text('Chưa có dữ liệu danh sách khám'), findsOneWidget);
    expect(find.text('Chưa có bệnh nhân đặt ca này'), findsNothing);
    expect(_totals(tester), [null, null, null]);
  });

  for (final width in [320.0, 390.0, 800.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('Details fit width $width with text scale $scale', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await _pump(tester, scale: scale);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Lê Hoàng Phúc'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('Mobile preview with the application font', (tester) async {
    tester.view.physicalSize = const Size(390, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    await (FontLoader('BeVietnamPro')..addFont(
          rootBundle.load(
            'assets/fonts/be_vietnam_pro/BeVietnamPro-Regular.ttf',
          ),
        ))
        .load();
    await _pump(tester, slotIndex: 2);
    await tester.pumpAndSettle();
    for (final part in ['top', 'list']) {
      if (part == 'list') {
        await tester.ensureVisible(find.text('Nguyễn Minh Anh'));
        await tester.pumpAndSettle();
      }
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('slot-preview')),
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('.dart_tool/doctor_slot_details_$part.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
    expect(tester.takeException(), isNull);
  });
}
