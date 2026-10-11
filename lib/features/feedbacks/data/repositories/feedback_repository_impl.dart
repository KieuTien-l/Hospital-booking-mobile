import '../../domain/entities/feedback_info.dart';
import '../../domain/repositories/feedback_repository.dart';
import '../datasources/feedback_firebase_datasource.dart';

class FeedbackRepositoryImpl implements FeedbackRepository {
  FeedbackRepositoryImpl(this._datasource);
  final FeedbackFirebaseDatasource _datasource;

  @override
  Future<void> submitFeedback(FeedbackInfo feedback) =>
      _datasource.submitFeedback(feedback);

  @override
  Future<List<FeedbackInfo>> getFeedbacksByPatient(String patientId) =>
      _datasource.getFeedbacksByPatient(patientId);
}

