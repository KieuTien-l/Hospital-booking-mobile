import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_4/core/themes/app_theme.dart';
import 'package:flutter_application_4/features/appointments/presentation/models/appointment_confirmation_ui_model.dart';
import 'package:flutter_application_4/features/appointments/presentation/models/appointment_time_ui_models.dart';
import 'package:flutter_application_4/features/appointments/presentation/models/booking_review_ui_model.dart';
import 'package:flutter_application_4/features/appointments/presentation/pages/appointment_information_page.dart';
import 'package:flutter_application_4/features/appointments/presentation/pages/booking_review_page.dart';
import 'package:flutter_application_4/features/profile/domain/entities/patient.dart';

void main() {
  final information = AppointmentConfirmationUiModel(
    specialtyName: 'Nội tổng quát',
    patient: const Patient(
      id: 'profile-1',
      authUserId: 'user',
      fullName: 'Nguyễn Văn An',
      phone: '0901234567',
      email: '',
      isActive: true,
      gender: 'MALE',
      address: 'TP. Hồ Chí Minh',
    ),
    fee: 150000,
    isDemoFee: true,
    selection: AppointmentTimeSelection(
      doctor: const AppointmentDoctorOption(
        id: 'doctor',
        name: 'BS. Nguyễn Văn A',
        location: 'Phòng 71 - Lầu 1 Khu B',
        session: 'Sáng',
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
  final item = AppointmentConfirmationResult(
    information: information,
    hasHealthInsurance: true,
    hasPrivateInsurance: false,
  );

  Future<void> show(
    WidgetTester tester,
    Widget page, {
    Size size = const Size(412, 915),
    double scale = 1,
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
        home: page,
      ),
    );
    await tester.pumpAndSettle();
  }

  test('Total remains unknown when any price is missing', () {
    expect(bookingReviewTotalLabel([item, item]), '300.000đ');
    final unknown = AppointmentConfirmationResult(
      information: AppointmentConfirmationUiModel(
        specialtyName: 'Khác',
        selection: information.selection,
      ),
      hasHealthInsurance: false,
      hasPrivateInsurance: false,
    );
    expect(bookingReviewTotalLabel([item, unknown]), 'Chưa có thông tin giá');
    expect(bookingReviewTotalLabel([]), '0đ');
  });

  testWidgets(
    'Profile toggle, insurance, delete callback and demo confirmation',
    (tester) async {
      AppointmentConfirmationResult? removed;
      await show(
        tester,
        BookingReviewPage(
          items: [item],
          onRemoveSpecialty: (value) => removed = value,
        ),
      );
      expect(find.text('Nguyễn Văn An'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('review-patient-toggle')));
      await tester.pumpAndSettle();
      expect(find.text('Nguyễn Văn An'), findsNothing);
      await tester.scrollUntilVisible(find.byTooltip('Xóa chuyên khoa'), 150);
      await tester.tap(find.byTooltip('Xóa chuyên khoa'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();
      expect(removed, isNull);
      await tester.tap(find.byTooltip('Xóa chuyên khoa'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xóa'));
      await tester.pumpAndSettle();
      expect(removed, same(item));
      expect(find.text('Chuyên khoa đã chọn (1)'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('BHYT'), 150);
      expect(find.text('Có'), findsOneWidget);
      expect(find.text('Không'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('confirm-booking-review')));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Giao diện xác nhận đã hoàn thành. Chức năng đặt khám sẽ được tích hợp sau.',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Continue opens review and back retains insurance', (
    tester,
  ) async {
    await show(tester, ConfirmAppointmentPage(information: information));
    for (final key in ['health-yes', 'private-no', 'continue-confirmation']) {
      final finder = find.byKey(ValueKey(key));
      await tester.scrollUntilVisible(finder, 150);
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }
    final page = tester.widget<BookingReviewPage>(
      find.byType(BookingReviewPage),
    );
    expect(page.items.single.information.patient, same(information.patient));
    expect(page.items.single.hasHealthInsurance, isTrue);
    expect(page.items.single.hasPrivateInsurance, isFalse);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('continue-confirmation')),
    );
    expect(
      tester
          .widget<ElevatedButton>(
            find.byKey(const ValueKey('continue-confirmation')),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('Successful live booking opens the success page', (tester) async {
    await show(
      tester,
      BookingReviewPage(items: [item], onSubmitBooking: (_) async => null),
    );
    await tester.tap(find.byKey(const ValueKey('confirm-booking-review')));
    await tester.pumpAndSettle();

    expect(find.text('Đặt lịch thành công'), findsOneWidget);
    expect(find.byKey(const ValueKey('booking-success-home')), findsOneWidget);
  });

  for (final size in [const Size(412, 915), const Size(320, 700)]) {
    testWidgets('Review fits $size with large text and fixed actions', (
      tester,
    ) async {
      await show(
        tester,
        BookingReviewPage(items: [item]),
        size: size,
        scale: 1.5,
      );
      await tester.scrollUntilVisible(find.text('Bảo hiểm tư nhân'), 150);
      expect(
        find.byKey(const ValueKey('confirm-booking-review')).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('Empty review disables confirmation', (tester) async {
    await show(tester, const BookingReviewPage(items: []));
    expect(
      tester
          .widget<ElevatedButton>(
            find.byKey(const ValueKey('confirm-booking-review')),
          )
          .onPressed,
      isNull,
    );
  });
}
