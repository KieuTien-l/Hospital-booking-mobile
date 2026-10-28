import 'package:flutter/material.dart';

import 'notifications_page.dart';

/// Compatibility entry point for older navigation code.
///
/// Notifications are now always loaded through [NotificationsPage] and its
/// NotificationController by the canonical patient profile id. The former
/// `userId` query missed server notifications that intentionally carry only
/// `patientId` (PayOS, completed visits, and appointment actions).
@Deprecated('Use NotificationsPage directly.')
class LiveNotificationsPage extends StatelessWidget {
  const LiveNotificationsPage({super.key, required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context) => const NotificationsPage();
}
