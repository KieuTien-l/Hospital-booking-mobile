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
    );
    await _firestore
        .collection(FeedbackModel.collectionName)
        .add(model.toFirestore());
  }
}

