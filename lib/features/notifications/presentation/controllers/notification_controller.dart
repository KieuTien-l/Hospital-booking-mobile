import 'dart:async';
import 'package:flutter/material.dart';
import '../../domain/entities/app_notification.dart';
import '../../domain/repositories/notification_repository.dart';

class NotificationController extends ChangeNotifier {
  final NotificationRepository _repository;
  StreamSubscription? _subscription;

  List<AppNotification> _notifications = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<AppNotification> get notifications => _notifications;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  NotificationController({required NotificationRepository repository})
      : _repository = repository;

  void loadNotificationsForPatient(String patientId) {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _subscription?.cancel();
    _subscription = _repository.getNotificationsForPatient(patientId).listen(
      (notifications) {
        _notifications = notifications;
        _isLoading = false;
        notifyListeners();
      },
      onError: (error) {
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
    _subscription?.cancel();
    super.dispose();
  }
}
