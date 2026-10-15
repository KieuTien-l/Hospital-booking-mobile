import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_4/core/state/view_state.dart';
import 'package:flutter_application_4/features/feedbacks/domain/errors/feedback_history_connection_exception.dart';
import 'package:flutter_application_4/features/feedbacks/domain/entities/feedback_info.dart';
import 'package:flutter_application_4/features/feedbacks/domain/repositories/feedback_repository.dart';
import 'package:flutter_application_4/features/feedbacks/presentation/controllers/feedback_controller.dart';

class _MemoryFeedbackRepository implements FeedbackRepository {
  final List<FeedbackInfo> saved = [];

  @override
  Future<List<FeedbackInfo>> getFeedbacksByPatient(String patientId) async =>
      saved.where((feedback) => feedback.patientId == patientId).toList();

  @override
  Future<void> submitFeedback(FeedbackInfo feedback) async {
    saved.add(feedback);
  }
}

class _FailingFeedbackRepository implements FeedbackRepository {
  @override
  Future<List<FeedbackInfo>> getFeedbacksByPatient(String patientId) async =>
      throw Exception('Không thể tải phản hồi');

  @override
  Future<void> submitFeedback(FeedbackInfo feedback) async =>
      throw Exception('Không thể gửi phản hồi');
}

class _OfflineFeedbackRepository implements FeedbackRepository {
  @override
  Future<List<FeedbackInfo>> getFeedbacksByPatient(String patientId) async =>
      throw const FeedbackHistoryConnectionException();

  @override
  Future<void> submitFeedback(FeedbackInfo feedback) async {}
}

void main() {
  test('rejects feedback without content or with a rating outside 1 to 5', () {
    final controller = FeedbackController(_MemoryFeedbackRepository());

    expect(
      controller.validateFeedback(
        const FeedbackInfo(
          id: '',
          patientId: 'patient-1',
          content: '   ',
          rating: 5,
        ),
      ),
      isNotNull,
    );
    expect(
      controller.validateFeedback(
        const FeedbackInfo(
          id: '',
          patientId: 'patient-1',
          content: 'Nội dung hợp lệ',
          rating: 6,
        ),
      ),
      isNotNull,
    );
  });

  test('saves and reloads feedback for the selected patient', () async {
    final repository = _MemoryFeedbackRepository();
    final controller = FeedbackController(repository);
    const feedback = FeedbackInfo(
      id: '',
      patientId: 'patient-1',
      title: 'Góp ý đặt lịch',
      category: 'suggestion',
      content: 'Mong muốn có thêm khung giờ khám buổi tối.',
      rating: 4,
    );

    expect(await controller.submitFeedback(feedback), isTrue);
    expect(repository.saved.single.title, 'Góp ý đặt lịch');
    expect(repository.saved.single.category, 'suggestion');

    await controller.loadFeedbacks('patient-1');
    expect(controller.status, ViewState.success);
    expect(controller.patientId, 'patient-1');
    expect(controller.feedbacks, [feedback]);
  });

  test(
    'exposes an error state when feedback history cannot be loaded',
    () async {
      final controller = FeedbackController(_FailingFeedbackRepository());

      await controller.loadFeedbacks('patient-1');

      expect(controller.status, ViewState.error);
      expect(controller.errorMessage, contains('Không thể tải phản hồi'));
    },
  );

  test('clears stale feedback and exposes an offline history state', () async {
    final controller = FeedbackController(_OfflineFeedbackRepository());

    await controller.loadFeedbacks('patient-1');

    expect(controller.status, ViewState.error);
    expect(controller.isHistoryUnavailable, isTrue);
    expect(controller.feedbacks, isEmpty);
  });
}
