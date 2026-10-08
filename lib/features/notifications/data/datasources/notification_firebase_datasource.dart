import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/notification_model.dart';

class NotificationFirebaseDatasource {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collectionPath = 'notifications';

  Stream<List<NotificationModel>> getNotificationsForPatient(String patientId) {
    return _firestore
        .collection(_collectionPath)
        .where('patientId', isEqualTo: patientId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => NotificationModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  Future<void> markAsRead(String notificationId) async {
    await _firestore
        .collection(_collectionPath)
        .doc(notificationId)
        .update({'isRead': true});
  }

  Future<void> markAllAsRead(String patientId) async {
    final snapshot = await _firestore
        .collection(_collectionPath)
        .where('patientId', isEqualTo: patientId)
        .where('isRead', isEqualTo: false)
        .get();

    final batch = _firestore.batch();
    for (var doc in snapshot.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }
}
