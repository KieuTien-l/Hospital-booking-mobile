import '../entities/feedback_info.dart';

abstract class FeedbackRepository {
  Future<void> submitFeedback(FeedbackInfo feedback);
}

