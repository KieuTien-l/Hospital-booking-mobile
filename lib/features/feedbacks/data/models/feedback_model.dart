import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/utils/model_value_parser.dart';
import '../../domain/entities/feedback_info.dart';

class FeedbackModel extends FeedbackInfo {
  const FeedbackModel({
    required super.id,
    required super.patientId,
    required super.content,
    required super.rating,
    super.createdAt,
  });

  static const String collectionName = 'PHAN_HOI';

  factory FeedbackModel.fromFirestore(DocumentSnapshot doc) {
    final raw = doc.data();
    final data = raw is Map<String, dynamic>
        ? raw
        : <String, dynamic>{};
    return FeedbackModel(
      id: doc.id,
      patientId: readReferenceId(data['patientId']),
      content: readString(data['content']),
      rating: readDouble(data['rating'], fallback: 5),
      createdAt: readDateTime(data['createdAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'patientId': patientId,
      'content': content,
      'rating': rating,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}

