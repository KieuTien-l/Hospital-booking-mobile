import '../../../../core/state/view_state.dart';
import '../../domain/entities/feedback_info.dart';
import '../../domain/repositories/feedback_repository.dart';

class FeedbackController extends ViewStateController {
  FeedbackController(this._repository);

  final FeedbackRepository _repository;

  String? validateFeedback(FeedbackInfo feedback) {
    if (feedback.content.trim().isEmpty) {
      return 'Nội dung phản hồi không được để trống';
    }
    if (feedback.rating < 1 || feedback.rating > 5) {
      return 'Số sao đánh giá không hợp lệ';
    }
    return null;
  }

  Future<bool> submitFeedback(FeedbackInfo feedback) async {
    final validationError = validateFeedback(feedback);
    if (validationError != null) {
      setState(ViewState.error, Exception(validationError));
      return false;
    }

    final token = beginRequest();
    try {
      await _repository.submitFeedback(feedback);
      if (!isCurrent(token)) return false;
      setState(ViewState.success);
      return true;
    } catch (error) {
      if (isCurrent(token)) setState(ViewState.error, error);
      return false;
    }
  }
}
