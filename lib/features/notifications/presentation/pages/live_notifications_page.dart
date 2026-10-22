import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/notification_item.dart';
import 'notifications_page.dart';

class LiveNotificationsPage extends StatefulWidget {
  const LiveNotificationsPage({super.key, required this.userId});
  final String userId;
  @override
  State<LiveNotificationsPage> createState() => _LiveNotificationsPageState();
}

class _LiveNotificationsPageState extends State<LiveNotificationsPage> {
  late Stream<QuerySnapshot<Map<String, dynamic>>> _stream;
  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void didUpdateWidget(covariant LiveNotificationsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) _listen();
  }

  void _listen() {
    _stream = FirebaseFirestore.instance
        .collection('THONG_BAO')
        .where('userId', isEqualTo: widget.userId)
        .where('status', isEqualTo: 'SENT')
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots();
  }

  Future<void> _mark(List<NotificationItem> items) async {
    final batch = FirebaseFirestore.instance.batch();
    for (final item in items.where((i) => !i.isRead && i.id.isNotEmpty)) {
      batch.update(
        FirebaseFirestore.instance.collection('THONG_BAO').doc(item.id),
        {'isRead': true, 'updatedAt': FieldValue.serverTimestamp()},
      );
    }
    await batch.commit();
  }

  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: _stream,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return ColoredBox(
          color: Colors.white,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Chưa tải được thông báo. Kiểm tra kết nối hoặc quyền truy cập.',
                  ),
                  TextButton(
                    onPressed: () => setState(_listen),
                    child: const Text('Thử lại'),
                  ),
                ],
              ),
            ),
          ),
        );
      }
      if (!snapshot.hasData) {
        return const ColoredBox(
          color: Colors.white,
          child: Center(child: CircularProgressIndicator()),
        );
      }
      final items = snapshot.data!.docs.map((doc) {
        final data = doc.data(), time = data['createdAt'];
        final date = time is Timestamp
            ? time.toDate().toUtc().add(const Duration(hours: 7))
            : null;
        return NotificationItem(
          id: doc.id,
          title: '${data['title'] ?? ''}',
          content: '${data['content'] ?? ''}',
          isRead: data['isRead'] == true,
          time: date == null
              ? 'Đang xác nhận thời gian'
              : '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
          publishedAt: date,
        );
      }).toList();
      return NotificationsPage(
        initialItems: items,
        onRead: (item) => _mark([item]),
        onReadAll: _mark,
      );
    },
  );
}
