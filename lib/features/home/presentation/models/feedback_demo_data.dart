import 'feedback_ui_model.dart';

abstract final class FeedbackDemoData {
  static const history = [
    FeedbackUiModel(
      title: 'Góp ý giao diện đặt khám',
      category: FeedbackCategory.suggestion,
      content: 'Mong muốn giao diện chọn ngày khám dễ quan sát hơn.',
      dateLabel: '10/10/2026 (minh họa)',
      status: FeedbackStatus.processing,
      rating: 4,
      isDemo: true,
    ),
    FeedbackUiModel(
      title: 'Đề xuất bổ sung hướng dẫn sử dụng',
      category: FeedbackCategory.improvement,
      content: 'Mong muốn có hướng dẫn chi tiết cho người dùng mới.',
      dateLabel: '09/10/2026 (minh họa)',
      status: FeedbackStatus.answered,
      response: 'Cảm ơn bạn đã đóng góp ý kiến. Chúng tôi sẽ xem xét đề xuất để cải thiện trải nghiệm sử dụng ứng dụng.',
      isDemo: true,
    ),
  ];
}
