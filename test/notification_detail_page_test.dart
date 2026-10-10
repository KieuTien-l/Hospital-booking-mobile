import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application_4/features/notifications/domain/entities/app_notification.dart';
import 'package:flutter_application_4/features/notifications/domain/repositories/notification_repository.dart';
import 'package:flutter_application_4/features/notifications/presentation/controllers/notification_controller.dart';
import 'package:flutter_application_4/features/notifications/presentation/models/notification_item.dart';
import 'package:flutter_application_4/features/notifications/presentation/pages/notification_detail_page.dart';
import 'package:flutter_application_4/features/notifications/presentation/pages/notifications_page.dart';

class _FakeNotificationRepository implements NotificationRepository {
  final _updates = StreamController<List<AppNotification>>.broadcast();
  List<AppNotification> _items = const [];

  @override
  Stream<List<AppNotification>> getNotificationsForPatient(String patientId) =>
      _updates.stream;

  void emit(List<AppNotification> items) {
    _items = List.unmodifiable(items);
    _updates.add(_items);
  }

  @override
  Future<void> markAsRead(String notificationId) async {
    emit(
      _items
          .map(
            (item) =>
                item.id == notificationId ? item.copyWith(isRead: true) : item,
          )
          .toList(),
    );
  }

  @override
  Future<void> markAllAsRead(String patientId) async =>
      emit(_items.map((item) => item.copyWith(isRead: true)).toList());

  Future<void> dispose() => _updates.close();
}

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
    final repository = _FakeNotificationRepository();
    final controller = NotificationController(repository);
    addTearDown(() async {
      controller.dispose();
      await repository.dispose();
    });
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: controller,
        child: const MaterialApp(home: Scaffold(body: NotificationsPage())),
      ),
    );
    controller.loadNotificationsForPatient('patient-1');
    repository.emit([
      AppNotification(
        id: 'notification-1',
        patientId: 'patient-1',
        title: item.title,
        content: item.content,
        createdAt: item.publishedAt!,
      ),
    ]);
    await tester.pump();
    await tester.tap(find.text(item.title.toUpperCase()));
    await tester.pumpAndSettle();
    expect(find.byType(NotificationDetailPage), findsOneWidget);
    expect(find.text('05/10/2026'), findsOneWidget);
    expect(find.text('08:16'), findsOneWidget);
    expect(find.text(item.content), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chưa đọc'));
    await tester.pumpAndSettle();
    expect(
      find.text('Các thông báo mới sẽ xuất hiện tại đây.'),
      findsOneWidget,
    );
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
