import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_4/features/appointments/presentation/models/payment_demo_data.dart';
import 'package:flutter_application_4/features/appointments/presentation/pages/payment_history_page.dart';
import 'package:flutter_application_4/features/appointments/presentation/pages/payment_receipt_page.dart';

import 'payment_flow_test.dart' show showPayment, tapPayment;

void main() {
  testWidgets('History filters and opens demo detail and receipt', (
    tester,
  ) async {
    await showPayment(
      tester,
      PaymentHistoryPage(
        transactions: PaymentDemoData.transactions,
        isDemo: true,
      ),
      scale: 1.5,
    );
    await tester.tap(find.widgetWithText(ChoiceChip, 'Thanh toán thành công'));
    await tester.pumpAndSettle();
    expect(find.text('DEMO-TT001'), findsNothing);
    await tapPayment(tester, 'DEMO-TT002');
    await tapPayment(tester, 'Xem biên lai mẫu');
    expect(find.byType(PaymentReceiptPage), findsOneWidget);
    expect(
      find.text('MẪU MINH HỌA • KHÔNG CÓ GIÁ TRỊ THANH TOÁN'),
      findsOneWidget,
    );
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('DEMO-TT002'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Empty history shows empty state', (tester) async {
    await showPayment(tester, const PaymentHistoryPage(transactions: []));
    expect(find.text('Chưa có giao dịch thanh toán.'), findsOneWidget);
  });
}
