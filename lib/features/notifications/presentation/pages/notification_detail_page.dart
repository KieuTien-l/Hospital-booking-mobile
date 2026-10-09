import 'package:flutter/material.dart';

import '../models/notification_item.dart';

class NotificationDetailPage extends StatelessWidget {
  const NotificationDetailPage({super.key, required this.item});
  final NotificationItem item;

  static const _blue = Color(0xFF0954C8);
  static const _body = Color(0xFF1B2B38);

  Widget _badge(IconData icon, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0xFFF1F5F9),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF687582)),
        const SizedBox(width: 6),
        Flexible(
          child: Text(label, style: const TextStyle(color: Color(0xFF687582))),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final date = item.publishedAt;
    String two(int value) => value.toString().padLeft(2, '0');
    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: Theme.of(context).textTheme
            .apply(fontFamily: 'BeVietnamPro'),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F7FC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          leading: const BackButton(color: _blue),
          title: const Text(
            'Thông báo',
            style: TextStyle(color: _body, fontWeight: FontWeight.w700),
          ),
        ),
        body: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title.toUpperCase(),
                        style: const TextStyle(
                          color: _blue,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (date != null) ...[
                            _badge(
                              Icons.calendar_today_outlined,
                              '${two(date.day)}/${two(date.month)}/${date.year}',
                            ),
                            _badge(
                              Icons.access_time,
                              '${two(date.hour)}:${two(date.minute)}',
                            ),
                          ] else
                            _badge(Icons.access_time, item.time),
                        ],
                      ),
                      const Divider(height: 32, color: Color(0xFFF1F5F9)),
                      SelectableText(
                        item.detailContent ?? item.content,
                        style: const TextStyle(
                          color: _body,
                          fontSize: 16,
                          height: 1.8,
                        ),
                      ),
                      if (item.eventTime?.isNotEmpty == true) ...[
                        const SizedBox(height: 20),
                        _detail('Thời gian: ', item.eventTime!),
                      ],
                      if (item.location?.isNotEmpty == true) ...[
                        const SizedBox(height: 20),
                        _detail('Địa điểm: ', item.location!),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _detail(String label, String value) => Text.rich(
    TextSpan(
      children: [
        TextSpan(
          text: label,
          style: const TextStyle(
            color: Color(0xFF687582),
            fontWeight: FontWeight.w700,
          ),
        ),
        TextSpan(text: value),
      ],
    ),
    style: const TextStyle(color: _body, fontSize: 16, height: 1.8),
  );
}
