import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application_4/features/chatbot/data/repositories/worker_chatbot_repository.dart';
import 'package:flutter_application_4/features/chatbot/domain/entities/chat_message.dart';
import 'package:flutter_application_4/features/chatbot/domain/repositories/chatbot_repository.dart';
import 'package:flutter_application_4/features/chatbot/presentation/controllers/chatbot_controller.dart';
import 'package:flutter_application_4/features/chatbot/presentation/pages/chatbot_page.dart';

class _Repository implements ChatbotRepository {
  Future<String> Function() respond = () async =>
      'Vào Đặt khám để chọn ca còn chỗ.';
  @override
  Future<String> sendMessage({
    required String message,
    required List<ChatMessage> history,
  }) => respond();
}

Future<void> capture(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('SPRINT6_CAPTURE')) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byType(RepaintBoundary).first,
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('build/sprint6-qa/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  Future<ChatbotController> show(
    WidgetTester tester,
    _Repository repository, {
    double textScale = 1,
  }) async {
    // Layout must use the shipped font in ordinary runs as well as screenshots.
    // Flutter's placeholder font can push long bubbles outside the scroll test.
    {
      await tester.runAsync(() async {
        await (FontLoader('BeVietnamPro')..addFont(
              rootBundle.load(
                'assets/fonts/be_vietnam_pro/BeVietnamPro-Regular.ttf',
              ),
            ))
            .load();
        await (FontLoader(
          'MaterialIcons',
        )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      });
    }
    final controller = ChatbotController(repository);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: controller,
        child: MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: const Size(320, 640),
              textScaler: TextScaler.linear(textScale),
            ),
            child: const ChatbotPage(),
          ),
        ),
      ),
    );
    return controller;
  }

  testWidgets(
    'AI-15: chat sends, shows loading, retries and keeps message order',
    (tester) async {
      final repository = _Repository();
      final pending = Completer<String>();
      repository.respond = () => pending.future;
      final controller = await show(tester, repository);
      await tester.enterText(find.byType(TextField), 'Hướng dẫn đặt khám');
      await tester.pump();
      await tester.tap(find.byTooltip('Gửi tin nhắn'));
      await tester.pumpAndSettle();
      expect(find.text('Trợ lý đang soạn câu trả lời…'), findsOneWidget);
      expect(controller.messages, hasLength(1));
      pending.completeError(const ChatbotException('Không thể kết nối.'));
      await tester.pumpAndSettle();
      expect(find.text('Không thể kết nối.'), findsOneWidget);
      await capture(tester, 'chat-error');
      repository.respond = () async => 'Vào Đặt khám để chọn ca còn chỗ.';
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      expect(controller.messages, hasLength(2));
      expect(
        tester.getTopLeft(find.text('Hướng dẫn đặt khám')).dy,
        lessThan(
          tester.getTopLeft(find.text('Vào Đặt khám để chọn ca còn chỗ.')).dy,
        ),
      );
      expect(tester.takeException(), isNull);
      await capture(tester, 'chat-success');
    },
  );
  testWidgets(
    'AI-15: 320px screen, keyboard, large text and long messages do not overflow',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 200);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      final pending = Completer<String>();
      final repository = _Repository()..respond = () => pending.future;
      final controller = await show(tester, repository, textScale: 1.8);
      await tester.enterText(
        find.byType(TextField),
        List.filled(35, 'Câu hỏi dài').join(' '),
      );
      await tester.pump();
      await tester.tap(find.byTooltip('Gửi tin nhắn'));
      await tester.pumpAndSettle();
      expect(controller.isSending, isTrue);
      await tester.scrollUntilVisible(
        find.text('Trợ lý đang soạn câu trả lời…'),
        200,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      pending.complete(List.filled(45, 'Nội dung hướng dẫn.').join(' '));
      await tester.pumpAndSettle();
      expect(controller.messages, hasLength(2));
      expect(tester.takeException(), isNull);
      await capture(tester, 'chat-mobile-long');
    },
  );
  testWidgets(
    'AI-12: private input is rejected without being shown in conversation',
    (tester) async {
      final controller = await show(tester, _Repository());
      await tester.enterText(find.byType(TextField), 'Mã OTP là 123456');
      await tester.pump();
      await tester.tap(find.byTooltip('Gửi tin nhắn'));
      await tester.pumpAndSettle();
      expect(controller.messages, isEmpty);
      expect(find.textContaining('quyền riêng tư'), findsOneWidget);
      expect(find.text('Mã OTP là 123456'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
