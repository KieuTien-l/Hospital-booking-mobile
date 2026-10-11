class FeedbackInfo {
  const FeedbackInfo({
    required this.id,
    required this.patientId,
    required this.content,
    required this.rating,
    this.title,
    this.category,
    this.createdAt,
  });

  final String id;
  final String patientId;
  final String content;
  final double rating;
  final String? title;
  final String? category;
  final DateTime? createdAt;
}

