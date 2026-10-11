import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_4/features/home/presentation/pages/patient_support_page.dart';

void main() {
  testWidgets('Support chat answers a common appointment question', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PatientSupportPage(kind: PatientSupportKind.chatbot),
      ),
    );

    await tester.tap(find.text('Cách đặt lịch khám?'));
    await tester.pump();

    expect(find.text('Cách đặt lịch khám?'), findsWidgets);
    expect(find.textContaining('Vào Đặt khám'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final item in const <(PatientSupportKind, String)>[
    (PatientSupportKind.servicePrices, 'Tra cứu chi phí khám'),
    (PatientSupportKind.contact, 'Kênh hỗ trợ trong HealWay'),
    (PatientSupportKind.policy, 'Quyền riêng tư và điều khoản'),
    (PatientSupportKind.settings, 'Thiết lập ứng dụng'),
  ]) {
    testWidgets('Support page ${item.$1.name} renders without an error', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(home: PatientSupportPage(kind: item.$1)),
      );

      expect(find.text(item.$2), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
