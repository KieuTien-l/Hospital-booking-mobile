import '../entities/app_notification.dart';

abstract class NotificationRepository {
  Stream<List<AppNotification>> getNotificationsForPatient(String patientId);
  Future<void> markAsRead(String notificationId);
  Future<void> markAllAsRead(String patientId);
}
