import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/notification_model.dart';

class NotificationFirebaseDatasource {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collectionPath = 'notifications';

  Stream<List<NotificationModel>> getNotificationsForPatient(String patientId) {
    return _firestore
        .collection(_collectionPath)
        .where('patientId', isEqualTo: patientId)
        .snapshots()
        .map((snapshot) {
          final notifications = snapshot.docs
              .map((doc) => NotificationModel.fromMap(doc.data(), doc.id))
              .toList();
          // Keeping the ordering in the client avoids a composite Firestore
          // index, and notification lists are small for an individual patient.
          notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return List.unmodifiable(notifications);
        });
  }

  Future<void> markAsRead(String notificationId) async {
    await _firestore.collection(_collectionPath).doc(notificationId).update({
      'isRead': true,
    });
  }

  Future<void> markAllAsRead(String patientId) async {
    final snapshot = await _firestore
        .collection(_collectionPath)
        .where('patientId', isEqualTo: patientId)
        .get();

    final batch = _firestore.batch();
    for (var doc in snapshot.docs) {
      if (doc.data()['isRead'] != true) {
        batch.update(doc.reference, {'isRead': true});
      }
    }
    await batch.commit();
  }
}
