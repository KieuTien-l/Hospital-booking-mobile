enum FeedbackCategory {
  suggestion('Góp ý'),
  issue('Phản ánh vấn đề'),
  improvement('Đề xuất cải thiện'),
  praise('Khen ngợi');

  const FeedbackCategory(this.label);
  final String label;
}

enum FeedbackStatus {
  pending('Chờ tiếp nhận'),
  processing('Đang xử lý'),
  answered('Đã phản hồi');

  const FeedbackStatus(this.label);
  final String label;
}

/// Presentation-only feedback; never represents a persisted submission.
class FeedbackUiModel {
  const FeedbackUiModel({
    required this.title,
    required this.content,
    required this.category,
    required this.dateLabel,
    required this.status,
    this.rating,
    this.response,
  });
  final String title;
  final String content;
  final FeedbackCategory category;
  final String dateLabel;
  final FeedbackStatus status;
  final int? rating;
  final String? response;
}
