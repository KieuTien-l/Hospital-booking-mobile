import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_4/core/themes/app_theme.dart';
import 'package:flutter_application_4/features/home/presentation/models/patient_function.dart';
import 'package:flutter_application_4/features/home/presentation/pages/functions_page.dart';

void main() {
  for (final width in [320.0, 412.0]) {
    testWidgets('Functions scroll and respond at width $width', (tester) async {
      tester.view.physicalSize = Size(width, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final opened = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: MediaQuery(
              data: MediaQueryData(
                size: Size(width, 700),
                textScaler: TextScaler.linear(1.5),
              ),
              child: FunctionsPage(onOpen: opened.add),
            ),
          ),
        ),
      );
      expect(find.text('Tiện ích khám bệnh'), findsOneWidget);
      expect(find.text('Hỗ trợ & Tiện ích'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right_rounded), findsNWidgets(8));
      expect(find.byType(NavigationBar), findsNothing);
      for (final feature in patientFunctions) {
        final title = feature.$1.replaceFirst(' (Chatbot)', '');
        final row = find.ancestor(
          of: find.text(title),
          matching: find.byType(InkWell),
        );
        await tester.ensureVisible(row);
        await tester.pumpAndSettle();
        // Tap the trailing edge to verify the whole row is interactive.
        await tester.tapAt(
          tester.getRect(row).centerRight - const Offset(8, 0),
        );
        await tester.pump();
        expect(opened.last, feature.$1);
        expect(tester.takeException(), isNull);
      }
    });
  }
}
