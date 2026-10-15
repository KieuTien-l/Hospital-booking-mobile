import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/errors/feedback_history_connection_exception.dart';
import '../models/feedback_model.dart';
import '../../domain/entities/feedback_info.dart';

class FeedbackFirebaseDatasource {
  FeedbackFirebaseDatasource(this._firestore);
  final FirebaseFirestore _firestore;

  Future<void> submitFeedback(FeedbackInfo feedback) async {
    final model = FeedbackModel(
      id: feedback.id,
      patientId: feedback.patientId,
      content: feedback.content,
      rating: feedback.rating,
      title: feedback.title,
      category: feedback.category,
    );
    await _firestore
        .collection(FeedbackModel.collectionName)
        .add(model.toFirestore());
  }

  Future<List<FeedbackModel>> getFeedbacksByPatient(String patientId) async {
    // Feedback history is a user-requested, up-to-date view.  Reading from
    // the server makes an offline request fail explicitly instead of silently
    // presenting an old Firestore cache as current data.
    try {
      final snapshot = await _firestore
          .collection(FeedbackModel.collectionName)
          .where('patientId', isEqualTo: patientId)
          .get(const GetOptions(source: Source.server));
      final feedbacks = snapshot.docs.map(FeedbackModel.fromFirestore).toList();
      feedbacks.sort(
        (left, right) =>
            (right.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
                .compareTo(
                  left.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0),
                ),
      );
      return feedbacks;
    } on FirebaseException catch (error) {
      if (error.code == 'unavailable') {
        throw const FeedbackHistoryConnectionException();
      }
      rethrow;
    }
  }
}
