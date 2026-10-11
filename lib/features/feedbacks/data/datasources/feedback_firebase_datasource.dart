import 'package:cloud_firestore/cloud_firestore.dart';
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
    final snapshot = await _firestore
        .collection(FeedbackModel.collectionName)
        .where('patientId', isEqualTo: patientId)
        .get();
    final feedbacks = snapshot.docs
        .map(FeedbackModel.fromFirestore)
        .toList();
    feedbacks.sort(
      (left, right) =>
          (right.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(
            left.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0),
          ),
    );
    return feedbacks;
  }
}

