import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_4/features/notifications/presentation/models/notification_item.dart';
import 'package:flutter_application_4/features/notifications/presentation/pages/notification_detail_page.dart';
import 'package:flutter_application_4/features/notifications/presentation/pages/notifications_page.dart';

void main() {
  final item = NotificationItem(
    title: 'Thông báo chương trình tư vấn sức khỏe',
    content: 'Nội dung tóm tắt',
    time: 'Hôm qua',
    publishedAt: DateTime(2026, 10, 5, 8, 16),
    detailContent: List.filled(
      12,
      'Nội dung chi tiết chương trình.',
    ).join('\n\n'),
    eventTime: '08:00 - 10:30',
    location: 'Sảnh trệt, khu A',
  );
  testWidgets('Opens selected detail and preserves read status on back', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: NotificationsPage(initialItems: [item])),
      ),
    );
    await tester.tap(find.text(item.title.toUpperCase()));
    await tester.pumpAndSettle();
    expect(find.byType(NotificationDetailPage), findsOneWidget);
    expect(find.text('05/10/2026'), findsOneWidget);
    expect(find.text('08:16'), findsOneWidget);
    expect(find.text(item.detailContent!), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chưa đọc'));
    await tester.pumpAndSettle();
    expect(find.text('Chưa có thông báo'), findsOneWidget);
  });
  testWidgets('Long details scroll without overflow on small screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(1.5)),
          child: child!,
        ),
        home: NotificationDetailPage(item: item),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -2000),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(item.markAsRead().detailContent, item.detailContent);
    expect(item.markAsRead().publishedAt, item.publishedAt);
  });
}
