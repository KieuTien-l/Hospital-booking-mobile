import '../../../../core/state/view_state.dart';
import '../../domain/errors/feedback_history_connection_exception.dart';
import '../../domain/entities/feedback_info.dart';
import '../../domain/repositories/feedback_repository.dart';

class FeedbackController extends ViewStateController {
  FeedbackController(this._repository);

  final FeedbackRepository _repository;
  List<FeedbackInfo> _feedbacks = const [];
  String? _patientId;
  bool _historyUnavailable = false;

  List<FeedbackInfo> get feedbacks => _feedbacks;
  String? get patientId => _patientId;
  bool get isHistoryUnavailable => _historyUnavailable;

  void _selectPatient(String patientId) {
    if (_patientId == patientId) return;
    _patientId = patientId;
    _feedbacks = const [];
    _historyUnavailable = false;
  }

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
    _selectPatient(feedback.patientId);
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

  Future<void> loadFeedbacks(String patientId) async {
    _selectPatient(patientId);
    _historyUnavailable = false;
    final token = beginRequest();
    try {
      final values = await _repository.getFeedbacksByPatient(patientId);
      if (!isCurrent(token)) return;
      _feedbacks = List.unmodifiable(values);
      setState(values.isEmpty ? ViewState.empty : ViewState.success);
    } catch (error) {
      if (isCurrent(token)) {
        // Do not present cached feedback as if it were a current server result.
        _feedbacks = const [];
        _historyUnavailable = error is FeedbackHistoryConnectionException;
        setState(ViewState.error, error);
      }
    }
  }
}
