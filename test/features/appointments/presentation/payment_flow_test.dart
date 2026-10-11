import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_4/core/themes/app_theme.dart';
import 'package:flutter_application_4/features/appointments/presentation/models/payment_demo_data.dart';
import 'package:flutter_application_4/features/appointments/presentation/models/payment_ui_model.dart';
import 'package:flutter_application_4/features/appointments/presentation/pages/booking_review_page.dart';
import 'package:flutter_application_4/features/appointments/presentation/pages/payment_information_page.dart';
import 'package:flutter_application_4/features/appointments/presentation/pages/payment_method_page.dart';
import 'package:flutter_application_4/features/appointments/presentation/pages/payment_processing_page.dart';
import 'package:flutter_application_4/features/appointments/presentation/pages/booking_success_page.dart';

Future<void> showPayment(
  WidgetTester tester,
  Widget page, {
  double scale = 1,
}) async {
  tester.view.physicalSize = const Size(320, 700);
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

Future<void> tapPayment(WidgetTester tester, String label) async {
  if (find.text(label).evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      find.text(label),
      150,
      scrollable: find.byType(Scrollable).last,
    );
  } else {
    await tester.ensureVisible(find.text(label));
  }
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Review passes original selections and payment method validates',
    (tester) async {
      final items = PaymentDemoData.transactions.first.items;
      await showPayment(tester, BookingReviewPage(items: items));
      await tester.tap(find.byKey(const ValueKey('confirm-booking-review')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<PaymentInformationPage>(find.byType(PaymentInformationPage))
            .items
            .first,
        same(items.first),
      );
      await tapPayment(tester, 'Chọn phương thức thanh toán');
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Tiếp tục thanh toán'),
            )
            .onPressed,
        isNull,
      );
      await tapPayment(tester, 'Ví điện tử MoMo');
      await tapPayment(tester, 'Chuyển khoản ngân hàng');
      expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
      await tapPayment(tester, 'Tiếp tục thanh toán');
      expect(
        tester
            .widget<PaymentProcessingPage>(find.byType(PaymentProcessingPage))
            .method,
        PaymentMethod.bankTransfer,
      );
      await tester.pump(const Duration(seconds: 20));
      expect(find.byType(BookingSuccessPage), findsNothing);
      await tapPayment(tester, 'Demo: Chờ xác nhận');
      expect(find.text('Xem đặt khám thành công (demo)'), findsNothing);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tapPayment(tester, 'Demo: Thanh toán thất bại');
      expect(find.text('Xem đặt khám thành công (demo)'), findsNothing);
      await tapPayment(tester, 'Thử lại');
      await tapPayment(tester, 'Demo: Thanh toán thành công');
      await tapPayment(tester, 'Xem đặt khám thành công (demo)');
      expect(find.byType(BookingSuccessPage), findsOneWidget);
      expect(find.text('Nguyễn Văn An'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Missing price disables payment', (tester) async {
    await showPayment(tester, const PaymentInformationPage(items: []));
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Chọn phương thức thanh toán'),
          )
          .onPressed,
      isNull,
    );
  });
  testWidgets('Methods fit larger text and non-demo has no simulation', (
    tester,
  ) async {
    final items = PaymentDemoData.transactions.first.items;
    await showPayment(tester, PaymentMethodPage(items: items), scale: 1.5);
    await tapPayment(tester, 'Quét mã QR');
    await tapPayment(tester, 'Tiếp tục thanh toán');
    expect(find.text('Demo: Thanh toán thành công'), findsNothing);
    expect(find.byType(BookingSuccessPage), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
