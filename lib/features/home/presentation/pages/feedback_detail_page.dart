import 'package:flutter/material.dart';

import '../models/feedback_ui_model.dart';
import '../widgets/patient_home_background.dart';
import '../widgets/feedback_rating.dart';

class FeedbackDetailPage extends StatelessWidget {
  const FeedbackDetailPage({super.key, required this.feedback});
  final FeedbackUiModel feedback;
  @override
  Widget build(BuildContext context) => PatientHomeBackground(
    child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text(
          'Chi tiết phản hồi',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text('Dữ liệu minh họa • Không phải phản hồi thực tế.'),
                const SizedBox(height: 16),
                Text(
                  feedback.title,
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Text(feedback.category.label),
                Text(feedback.dateLabel),
                Text('${feedback.status.label} (Demo)'),
                if (feedback.rating != null)
                  Text(
                    'Đánh giá: ${feedback.rating}/5 sao — ${FeedbackRating.labels[feedback.rating! - 1]}',
                  ),
                const SizedBox(height: 20),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Text(
                      feedback.content,
                      style: const TextStyle(height: 1.6),
                    ),
                  ),
                ),
                if (feedback.response != null) ...[
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Phản hồi từ HealWay (minh họa)',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            feedback.response!,
                            style: const TextStyle(height: 1.6),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
