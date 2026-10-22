import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_4/features/home/presentation/pages/patient_support_page.dart';

void main() {
  Future<void> capture(WidgetTester tester, String name) async {
    if (!const bool.fromEnvironment('ADMIN_CAPTURE')) return;
    await tester.runAsync(() async {
      await (FontLoader('BeVietnamPro')..addFont(
            rootBundle.load(
              'assets/fonts/be_vietnam_pro/BeVietnamPro-Regular.ttf',
            ),
          ))
          .load();
    });
    await tester.pumpAndSettle();
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byType(RepaintBoundary).first,
    );
    await tester.runAsync(() async {
      final picture = await boundary.toImage();
      final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
      final file = File('build/admin-preview/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      picture.dispose();
    });
  }

  testWidgets('Support chat answers a common appointment question', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PatientSupportPage(kind: PatientSupportKind.chatbot),
      ),
    );

    await tester.tap(find.text('Cách đặt lịch khám?'));
    await tester.pumpAndSettle();

    expect(find.text('Cách đặt lịch khám?'), findsWidgets);
    expect(find.textContaining('Vào Đặt khám'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await capture(tester, 'chat-conversation');
  });

  testWidgets(
    'Chat preserves order, disables duplicate sends and retries errors',
    (tester) async {
      var response = Completer<String>();
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: PatientSupportPage(
            kind: PatientSupportKind.chatbot,
            answerQuestion: (_) {
              calls++;
              return response.future;
            },
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), 'Một câu hỏi');
      await tester.tap(find.byTooltip('Gửi câu hỏi'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump();
      expect(find.text('HealWay đang trả lời…'), findsOneWidget);
      await tester.tap(find.byTooltip('Gửi câu hỏi'));
      expect(calls, 1);
      response.completeError(StateError('offline'));
      await tester.pumpAndSettle();
      expect(
        find.text('Chưa nhận được câu trả lời. Vui lòng thử lại.'),
        findsOneWidget,
      );
      response = Completer<String>();
      await tester.tap(find.text('Thử lại'));
      await tester.pump();
      response.complete('Câu trả lời sau khi kết nối lại');
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(find.text('Một câu hỏi'), findsOneWidget);
      expect(find.text('Câu trả lời sau khi kết nối lại'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Một câu hỏi')).dy,
        lessThan(
          tester.getTopLeft(find.text('Câu trả lời sau khi kết nối lại')).dy,
        ),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Chat fits long messages, large text and phone keyboard', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 200);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 640),
            textScaler: TextScaler.linear(1.8),
            viewInsets: EdgeInsets.only(bottom: 200),
          ),
          child: PatientSupportPage(
            kind: PatientSupportKind.chatbot,
            answerQuestion: (_) async =>
                List.filled(60, 'Nội dung hướng dẫn dài.').join(' '),
          ),
        ),
      ),
    );
    await tester.enterText(
      find.byType(TextField),
      List.filled(30, 'Câu hỏi dài').join(' '),
    );
    await tester.tap(find.byTooltip('Gửi câu hỏi'));
    await tester.pumpAndSettle();
    expect(find.text('HealWay đang trả lời…'), findsNothing);
    expect(tester.takeException(), isNull);
    await capture(tester, 'chat-long-mobile');
  });

  testWidgets('Closing chat while a reply is pending is safe', (tester) async {
    final response = Completer<String>();
    await tester.pumpWidget(
      MaterialApp(
        home: PatientSupportPage(
          kind: PatientSupportKind.chatbot,
          answerQuestion: (_) => response.future,
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'Câu hỏi');
    await tester.tap(find.byTooltip('Gửi câu hỏi'));
    await tester.pumpWidget(const SizedBox.shrink());
    response.complete('Trả lời');
    await tester.pumpAndSettle();
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
