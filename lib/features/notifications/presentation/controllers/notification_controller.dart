import 'dart:async';

import 'package:flutter/material.dart';

import '../../domain/entities/app_notification.dart';
import '../../domain/repositories/notification_repository.dart';

class NotificationController extends ChangeNotifier {
  NotificationController(this._repository);

  final NotificationRepository _repository;
  StreamSubscription? _subscription;

  List<AppNotification> _notifications = [];
  bool _isLoading = false;
  String? _errorMessage;
  String? _patientId;
  var _subscriptionRequest = 0;

  List<AppNotification> get notifications => _notifications;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get patientId => _patientId;

  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  void loadNotificationsForPatient(String patientId) {
    final request = ++_subscriptionRequest;
    _patientId = patientId;
    _notifications = [];
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _subscription?.cancel();
    _subscription = _repository
        .getNotificationsForPatient(patientId)
        .listen(
          (notifications) {
            if (request != _subscriptionRequest) return;
            _notifications = notifications;
            _isLoading = false;
            notifyListeners();
          },
          onError: (error) {
            if (request != _subscriptionRequest) return;
            _errorMessage = error.toString();
            _isLoading = false;
            notifyListeners();
          },
        );
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await _repository.markAsRead(notificationId);
      // Local state will update via the stream
    } catch (e) {
      debugPrint('Failed to mark notification as read: $e');
    }
  }

  Future<void> markAllAsRead(String patientId) async {
    try {
      await _repository.markAllAsRead(patientId);
      // Local state will update via the stream
    } catch (e) {
      debugPrint('Failed to mark all notifications as read: $e');
    }
  }

  @override
  void dispose() {
    _subscriptionRequest++;
    _subscription?.cancel();
    super.dispose();
  }
}
