import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_4/core/themes/app_theme.dart';
import 'package:flutter_application_4/features/home/presentation/models/feedback_demo_data.dart';
import 'package:flutter_application_4/features/home/presentation/pages/customer_feedback_page.dart';

Future<void> showFeedback(
  WidgetTester tester, {
  bool empty = false,
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
      home: CustomerFeedbackPage(
        history: empty ? const [] : FeedbackDemoData.history,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> reveal(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      140,
      scrollable: find
          .byWidgetPredicate(
            (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
          )
          .last,
    );
  }
  await Scrollable.ensureVisible(tester.element(finder), alignment: .5);
  await tester.pumpAndSettle();
}

Future<void> tapFeedback(WidgetTester tester, String label) async {
  await reveal(tester, find.text(label));
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Validation blocks submission and draft survives tabs and demo', (
    tester,
  ) async {
    await showFeedback(tester);
    await reveal(tester, find.byKey(const ValueKey('feedback-submit')));
    await tester.tap(find.byKey(const ValueKey('feedback-submit')));
    await tester.pumpAndSettle();
    expect(
      find.text('Phản hồi mẫu đã được ghi nhận trong phiên demo'),
      findsNothing,
    );
    await tapFeedback(tester, 'Góp ý');
    await reveal(tester, find.byTooltip('4 sao: Hài lòng'));
    await tester.tap(find.byTooltip('4 sao: Hài lòng'));
    await tester.pumpAndSettle();
    await reveal(tester, find.byKey(const ValueKey('feedback-title')));
    await tester.enterText(
      find.byKey(const ValueKey('feedback-title')),
      'Góp ý mới',
    );
    await reveal(tester, find.byKey(const ValueKey('feedback-content')));
    await tester.enterText(
      find.byKey(const ValueKey('feedback-content')),
      'Nội dung góp ý đủ dài để gửi demo.',
    );
    await tapFeedback(tester, 'Lịch sử');
    await tapFeedback(tester, 'Chia sẻ phản hồi');
    await reveal(tester, find.byKey(const ValueKey('feedback-title')));
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('feedback-title')))
          .controller!
          .text,
      'Góp ý mới',
    );
    await tapFeedback(tester, 'Gửi phản hồi');
    expect(
      find.text('Phản hồi mẫu đã được ghi nhận trong phiên demo'),
      findsOneWidget,
    );
    await tapFeedback(tester, 'Xem lịch sử mẫu');
    await tapFeedback(tester, 'Góp ý mới');
    expect(find.text('Chi tiết phản hồi'), findsOneWidget);
    expect(find.text('Nội dung góp ý đủ dài để gửi demo.'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Lịch sử mẫu • Chỉ lưu trong phiên demo, chưa gửi đến hệ thống.',
      ),
      findsOneWidget,
    );
    expect(find.text('Liên kết hồ sơ'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Filters show empty state and detail retains history tab', (
    tester,
  ) async {
    await showFeedback(tester, scale: 1.5);
    await tapFeedback(tester, 'Lịch sử');
    await tapFeedback(tester, 'Chờ tiếp nhận');
    await reveal(tester, find.text('Chưa có chia sẻ phản hồi'));
    expect(find.text('Chưa có chia sẻ phản hồi'), findsOneWidget);
    await tapFeedback(tester, 'Đã phản hồi');
    await tapFeedback(tester, 'Đề xuất bổ sung hướng dẫn sử dụng');
    await reveal(tester, find.text('Phản hồi từ HealWay (minh họa)'));
    expect(find.text('Phản hồi từ HealWay (minh họa)'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Đã phản hồi'))
          .selected,
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('Empty history can return to form', (tester) async {
    await showFeedback(tester, empty: true);
    await tapFeedback(tester, 'Lịch sử');
    await tapFeedback(tester, 'Thêm chia sẻ phản hồi');
    expect(find.text('Ý kiến của bạn rất quan trọng'), findsOneWidget);
  });
}
