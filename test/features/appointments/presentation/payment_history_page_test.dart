import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_4/features/appointments/presentation/models/payment_demo_data.dart';
import 'package:flutter_application_4/features/appointments/presentation/models/payment_ui_model.dart';
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

  testWidgets('A Firestore payment uses its saved amount, not demo data', (
    tester,
  ) async {
    await showPayment(
      tester,
      PaymentHistoryPage(
        transactions: [
          PaymentUiModel(
            items: const [],
            method: PaymentMethod.momo,
            status: PaymentStatus.success,
            transactionId: 'TT-THAT-001',
            amount: 250000,
            timestamp: DateTime(2026, 10, 11, 9, 30),
          ),
        ],
      ),
    );

    expect(find.text('TT-THAT-001'), findsOneWidget);
    expect(find.text('250.000đ'), findsOneWidget);
    expect(find.text('Giao dịch minh họa'), findsNothing);
  });
}
