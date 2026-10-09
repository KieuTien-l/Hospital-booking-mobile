import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_4/core/themes/app_theme.dart';
import 'package:flutter_application_4/features/appointments/presentation/models/appointment_confirmation_ui_model.dart';
import 'package:flutter_application_4/features/appointments/presentation/models/appointment_time_ui_models.dart';
import 'package:flutter_application_4/features/appointments/presentation/pages/appointment_information_page.dart';
import 'package:flutter_application_4/features/appointments/presentation/widgets/insurance_choice_card.dart';

void main() {
  final information = AppointmentConfirmationUiModel(
    specialtyName: 'Chuyên khoa Nội tổng quát và chăm sóc sức khỏe',
    patientName: 'Nguyễn Thị B',
    fee: 150000,
    isDemoFee: true,
    selection: AppointmentTimeSelection(
      doctor: const AppointmentDoctorOption(
        id: 'custom',
        name: 'BSCKII. Nguyễn Văn A',
        location: 'Phòng 71 - Lầu 1 Khu B',
        session: 'Buổi sáng',
        schedule: {},
      ),
      date: DateTime(2026, 10, 14),
      slot: const AppointmentTimeOption(
        id: 'slot',
        workScheduleId: 'schedule',
        label: '08:30 - 09:30',
      ),
    ),
  );

  Future<void> show(
    WidgetTester tester, {
    AppointmentConfirmationUiModel? data,
    ValueChanged<AppointmentConfirmationResult>? onContinue,
    double scale = 1,
    Size size = const Size(412, 915),
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
        home: ConfirmAppointmentPage(
          information: data ?? information,
          onContinue: onContinue,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> reveal(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(finder, 150);
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
  }

  Future<void> choose(WidgetTester tester, String key) async {
    final finder = find.byKey(ValueKey(key));
    await reveal(tester, finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<bool> enabled(WidgetTester tester) async {
    final finder = find.byKey(const ValueKey('continue-confirmation'));
    await reveal(tester, finder);
    return tester.widget<ElevatedButton>(finder).onPressed != null;
  }

  testWidgets('Selected information and sample fee are displayed', (
    tester,
  ) async {
    await show(tester);
    for (final text in [
      'Nguyễn Thị B',
      information.specialtyName,
      '14/10/2026',
      '08:30 - 09:30',
      'BSCKII. Nguyễn Văn A',
      'Phòng 71 - Lầu 1 Khu B',
      '150.000đ',
      'Giá minh họa',
    ]) {
      await reveal(tester, find.text(text));
      expect(find.text(text), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  for (final health in [true, false]) {
    for (final private in [true, false]) {
      testWidgets(
        'Insurance answers $health / $private validate independently',
        (tester) async {
          AppointmentConfirmationResult? result;
          await show(tester, onContinue: (value) => result = value);
          expect(await enabled(tester), isFalse);
          await choose(tester, 'health-${health ? 'yes' : 'no'}');
          expect(await enabled(tester), isFalse);
          await choose(tester, 'private-${private ? 'yes' : 'no'}');
          expect(await enabled(tester), isTrue);
          await choose(tester, 'continue-confirmation');
          expect(result!.hasHealthInsurance, health);
          expect(result!.hasPrivateInsurance, private);
          expect(result!.information, same(information));
          await choose(tester, 'health-${health ? 'no' : 'yes'}');
          expect(await enabled(tester), isTrue);
          await reveal(tester, find.byType(InsuranceChoiceCard).first);
          final card = tester.widget<InsuranceChoiceCard>(
            find.byType(InsuranceChoiceCard).first,
          );
          expect(card.value, !health);
        },
      );
    }
  }
  testWidgets(
    'Private answer alone is insufficient and add specialty preserves choices',
    (tester) async {
      await show(tester);
      await choose(tester, 'private-no');
      expect(await enabled(tester), isFalse);
      await choose(tester, 'health-no');
      await reveal(tester, find.text('Thêm chuyên khoa'));
      await tester.tap(find.text('Thêm chuyên khoa'));
      await tester.pumpAndSettle();
      expect(
        find.text('Chức năng thêm chuyên khoa chưa được hỗ trợ.'),
        findsOneWidget,
      );
      expect(await enabled(tester), isTrue);
    },
  );
  testWidgets('Missing fee and profile are not replaced by demo data', (
    tester,
  ) async {
    await show(
      tester,
      data: AppointmentConfirmationUiModel(
        specialtyName: 'Da liễu',
        selection: information.selection,
      ),
    );
    expect(find.text('Hồ sơ bệnh nhân'), findsNothing);
    await reveal(tester, find.text('Chưa có thông tin'));
    expect(find.text('150.000đ'), findsNothing);
    expect(find.text('Giá minh họa'), findsNothing);
  });
  for (final size in [const Size(412, 915), const Size(320, 700)]) {
    testWidgets('Long text fits $size with large text', (tester) async {
      await show(tester, size: size, scale: 1.5);
      await choose(tester, 'health-yes');
      await choose(tester, 'private-no');
      expect(await enabled(tester), isTrue);
      expect(tester.takeException(), isNull);
    });
  }
}
