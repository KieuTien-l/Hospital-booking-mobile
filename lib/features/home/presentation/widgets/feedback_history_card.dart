import 'package:flutter/material.dart';

import '../models/feedback_ui_model.dart';
import '../../../../core/themes/app_colors.dart';

class FeedbackHistoryCard extends StatelessWidget {
  const FeedbackHistoryCard({
    super.key,
    required this.feedback,
    required this.onTap,
  });
  final FeedbackUiModel feedback;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    feedback.title,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(feedback.category.label),
                  Text(feedback.dateLabel),
                  const SizedBox(height: 8),
                  Text(
                    feedback.content,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${feedback.status.label} (Demo)',
                    style: const TextStyle(color: AppColors.textOnPrimary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    ),
  );
}
