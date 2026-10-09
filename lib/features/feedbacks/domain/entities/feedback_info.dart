class FeedbackInfo {
  const FeedbackInfo({
    required this.id,
    required this.patientId,
    required this.content,
    required this.rating,
    this.createdAt,
  });

  final String id;
  final String patientId;
  final String content;
  final double rating;
  final DateTime? createdAt;
}

