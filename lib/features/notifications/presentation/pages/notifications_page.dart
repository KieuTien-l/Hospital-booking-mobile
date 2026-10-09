import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/widgets/view_state_widgets.dart';
import '../../../profile/presentation/controllers/patient_profile_controller.dart';
import '../../domain/entities/app_notification.dart';
import '../controllers/notification_controller.dart';

/// Content only: the patient shell owns the bottom navigation.
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

abstract final class _NotificationColors {
  static const title = Color(0xFF1B2B38);
  static const blue = Color(0xFF0954C8);
  static const body = Color(0xFF687582);
  static const soft = Color(0xFFF1F5FF);
}

class _NotificationsPageState extends State<NotificationsPage> {
  bool _unreadOnly = false;
  String? _loadedPatientId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadNotificationsFor(
        context.read<PatientProfileController?>()?.patient?.id,
      );
    });
  }

  void _loadNotificationsFor(String? patientId) {
    if (!mounted ||
        patientId == null ||
        patientId.isEmpty ||
        patientId == _loadedPatientId) {
      return;
    }
    _loadedPatientId = patientId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _loadedPatientId == patientId) {
        context
            .read<NotificationController>()
            .loadNotificationsForPatient(patientId);
      }
    });
  }

  void _open(AppNotification item) {
    if (!item.isRead) {
      context.read<NotificationController>().markAsRead(item.id);
    }

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title.toUpperCase(),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Text(
                _formatTime(item.createdAt),
                style: const TextStyle(color: _NotificationColors.body),
              ),
              const SizedBox(height: 16),
              Text(item.content, style: const TextStyle(height: 1.6)),
              const SizedBox(height: 24),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Đóng'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} phút trước';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} giờ trước';
    } else {
      return '${time.day}/${time.month}/${time.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<NotificationController?>();
    if (controller == null) {
      return const _NotificationPreview();
    }
    final patientId = context
        .watch<PatientProfileController?>()
        ?.patient
        ?.id;
    _loadNotificationsFor(patientId);
    final items = controller.notifications;
    final visible = items
        .where((item) => !_unreadOnly || !item.isRead)
        .toList();
    final hasUnread = controller.unreadCount > 0;

    return ColoredBox(
      color: Colors.white,
      child: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Thông báo',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontSize: 24,
                      color: _NotificationColors.title,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: hasUnread
                        ? () {
                            if (patientId != null) {
                              controller.markAllAsRead(patientId);
                            }
                          }
                        : null,
                    style: TextButton.styleFrom(
                      backgroundColor: _NotificationColors.soft,
                      foregroundColor: _NotificationColors.blue,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      shape: const StadiumBorder(),
                    ),
                    icon: const Icon(Icons.done_all_rounded, size: 18),
                    label: const Text('Đọc tất cả'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  _filter('Tất cả', false),
                  const SizedBox(width: 12),
                  _filter('Chưa đọc', true),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ColoredBox(
                color: const Color(0xFFF6F7F9),
                child: controller.isLoading
                    ? const AppLoadingWidget(message: 'Đang tải thông báo...')
                    : controller.errorMessage != null
                    ? AppErrorWidget(
                        message: controller.errorMessage!,
                        onRetry: () {
                          if (patientId != null) {
                            controller.loadNotificationsForPatient(patientId);
                          }
                        },
                      )
                    : visible.isEmpty
                    ? const AppEmptyWidget(
                        message: 'Các thông báo mới sẽ xuất hiện tại đây.',
                        icon: Icons.notifications_none_rounded,
                      )
                    : ListView.separated(
                        key: const PageStorageKey('patient-notifications'),
                        padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
                        itemCount: visible.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) => _NotificationCard(
                          item: visible[index],
                          onTap: () => _open(visible[index]),
                          timeStr: _formatTime(visible[index].createdAt),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filter(String label, bool unread) {
    final selected = _unreadOnly == unread;
    return Expanded(
      child: Semantics(
        selected: selected,
        child: TextButton(
          onPressed: () => setState(() => _unreadOnly = unread),
          style: TextButton.styleFrom(
            foregroundColor: selected
                ? _NotificationColors.blue
                : _NotificationColors.body,
            backgroundColor: selected
                ? _NotificationColors.soft
                : Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                height: 3,
                width: 32,
                decoration: BoxDecoration(
                  color: selected
                      ? _NotificationColors.blue
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A lightweight fallback for isolated widget previews. The production app
/// always supplies NotificationController from App's provider tree.
class _NotificationPreview extends StatefulWidget {
  const _NotificationPreview();

  @override
  State<_NotificationPreview> createState() => _NotificationPreviewState();
}

class _NotificationPreviewState extends State<_NotificationPreview> {
  bool _unreadOnly = false;
  var _items = <AppNotification>[
    AppNotification(
      id: 'preview-appointment',
      patientId: 'preview-patient',
      title: 'Lịch khám đã được xác nhận',
      content: 'Lịch hẹn của bạn đã được xác nhận.',
      createdAt: DateTime(2026, 1, 1),
    ),
    AppNotification(
      id: 'preview-welcome',
      patientId: 'preview-patient',
      title: 'Chào mừng bạn đến với HealWay',
      content: 'Cảm ơn bạn đã sử dụng ứng dụng.',
      createdAt: DateTime(2026, 1, 1),
      isRead: true,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final visible = _items.where((item) => !_unreadOnly || !item.isRead).toList();
    return ColoredBox(
      color: Colors.white,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Thông báo',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(
                    () => _items = _items
                        .map((item) => item.copyWith(isRead: true))
                        .toList(),
                  ),
                  child: const Text('Đọc tất cả'),
                ),
              ],
            ),
          ),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => setState(() => _unreadOnly = false),
                  child: const Text('Tất cả'),
                ),
              ),
              Expanded(
                child: TextButton(
                  onPressed: () => setState(() => _unreadOnly = true),
                  child: const Text('Chưa đọc'),
                ),
              ),
            ],
          ),
          Expanded(
            child: visible.isEmpty
                ? const Center(child: Text('CHƯA CÓ THÔNG BÁO'))
                : ListView(
                    children: visible
                        .map(
                          (item) => ListTile(
                            title: Text(item.title.toUpperCase()),
                            subtitle: Text(item.content),
                          ),
                        )
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.item,
    required this.onTap,
    required this.timeStr,
  });
  final AppNotification item;
  final VoidCallback onTap;
  final String timeStr;

  @override
  Widget build(BuildContext context) => Semantics(
    label: item.isRead ? 'Đã đọc' : 'Chưa đọc',
    child: Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _NotificationColors.title.withValues(alpha: .04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF3F6F9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.notifications_none_rounded,
                    color: _NotificationColors.body,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.4,
                          color: item.isRead
                              ? _NotificationColors.title
                              : _NotificationColors.blue,
                          fontWeight: item.isRead
                              ? FontWeight.w500
                              : FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.content,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color: _NotificationColors.body,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        timeStr,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: _NotificationColors.body,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  children: [
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: _NotificationColors.body,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
