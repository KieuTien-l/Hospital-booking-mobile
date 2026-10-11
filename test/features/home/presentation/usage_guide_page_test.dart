import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_4/core/themes/app_theme.dart';
import 'package:flutter_application_4/features/home/presentation/models/usage_guide_demo_data.dart';
import 'package:flutter_application_4/features/home/presentation/pages/usage_guide_page.dart';

Future<void> showHelp(WidgetTester tester, {double scale = 1}) async {
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
      home: const UsageGuidePage(),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> tapHelp(WidgetTester tester, String text) async {
  if (find.text(text).evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      find.text(text),
      140,
      scrollable: find
          .byWidgetPredicate(
            (widget) =>
                widget is Scrollable &&
                widget.axisDirection == AxisDirection.down,
          )
          .last,
    );
  }
  await Scrollable.ensureVisible(
    tester.element(find.text(text)),
    alignment: .5,
  );
  await tester.pumpAndSettle();
  for (
    var i = 0;
    i < 15 && find.text(text).hitTestable().evaluate().isEmpty;
    i++
  ) {
    final target = find.text(text);
    final below =
        target.evaluate().isNotEmpty && tester.getCenter(target).dy > 350;
    await tester.dragFrom(
      const Offset(160, 500),
      Offset(0, below ? -100 : 100),
    );
    await tester.pumpAndSettle();
  }
  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('All four procedures open correct steps and return', (
    tester,
  ) async {
    await showHelp(tester, scale: 1.5);
    expect(UsageGuideDemoData.guides, hasLength(4));
    for (final guide in UsageGuideDemoData.guides) {
      await tapHelp(tester, guide.title);
      expect(find.text('Chi tiết hướng dẫn'), findsOneWidget);
      expect(find.text(guide.steps.first), findsOneWidget);
      await tapHelp(tester, 'Đã hiểu');
      expect(find.text('Hướng dẫn sử dụng'), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });
  testWidgets('FAQ filters, search, empty state and back preserve state', (
    tester,
  ) async {
    await showHelp(tester);
    await tapHelp(tester, 'Câu hỏi thường gặp');
    expect(UsageGuideDemoData.faqs, hasLength(4));
    await tapHelp(tester, 'Đặt khám');
    await tester.enterText(find.byType(TextField), 'người thân');
    await tester.pumpAndSettle();
    final faq = UsageGuideDemoData.faqs[1];
    await tapHelp(tester, faq.question);
    expect(find.text(faq.answer), findsOneWidget);
    await tapHelp(tester, 'Quay lại');
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'người thân',
    );
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Đặt khám'))
          .selected,
      isTrue,
    );
    await tester.enterText(find.byType(TextField), 'không có câu hỏi này');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Không tìm thấy câu hỏi phù hợp.'));
    expect(find.text('Không tìm thấy câu hỏi phù hợp.'), findsOneWidget);
    await Scrollable.ensureVisible(
      tester.element(find.byTooltip('Xóa tìm kiếm')),
      alignment: .5,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Xóa tìm kiếm'));
    await tester.pumpAndSettle();
    await tapHelp(tester, 'Tất cả');
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
    for (final item in UsageGuideDemoData.faqs) {
      await tester.dragFrom(const Offset(160, 500), const Offset(0, 1200));
      await tester.pumpAndSettle();
      await tapHelp(tester, item.question);
      expect(find.text(item.answer), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
  });
  testWidgets('Contact opens support and FAQ fits large text', (
    tester,
  ) async {
    await showHelp(tester, scale: 1.5);
    await tapHelp(tester, 'Liên hệ');
    expect(find.text('Kênh hỗ trợ trong HealWay'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tapHelp(tester, 'Câu hỏi thường gặp');
    await tapHelp(tester, 'Thanh toán');
    await tapHelp(tester, UsageGuideDemoData.faqs.last.question);
    expect(find.text(UsageGuideDemoData.faqs.last.answer), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
