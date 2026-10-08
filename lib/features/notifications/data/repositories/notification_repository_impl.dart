import '../../domain/entities/app_notification.dart';
import '../../domain/repositories/notification_repository.dart';
import '../datasources/notification_firebase_datasource.dart';

class NotificationRepositoryImpl implements NotificationRepository {
  final NotificationFirebaseDatasource _datasource;

  NotificationRepositoryImpl(this._datasource);

  @override
  Stream<List<AppNotification>> getNotificationsForPatient(String patientId) {
    return _datasource.getNotificationsForPatient(patientId);
  }

  @override
  Future<void> markAsRead(String notificationId) {
    return _datasource.markAsRead(notificationId);
  }

  @override
  Future<void> markAllAsRead(String patientId) {
    return _datasource.markAllAsRead(patientId);
  }
}
