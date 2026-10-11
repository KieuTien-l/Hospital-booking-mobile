import 'package:flutter/material.dart';

import '../../../../core/themes/app_colors.dart';

class FeedbackRating extends StatelessWidget {
  const FeedbackRating({
    super.key,
    required this.value,
    required this.onChanged,
  });
  final int? value;
  final ValueChanged<int?> onChanged;
  static const labels = [
    'Rất không hài lòng',
    'Không hài lòng',
    'Bình thường',
    'Hài lòng',
    'Rất hài lòng',
  ];
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Mức độ hài lòng (tùy chọn)',
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
      Wrap(
        children: [
          for (var star = 1; star <= 5; star++)
            IconButton(
              tooltip: '$star sao: ${labels[star - 1]}',
              onPressed: () => onChanged(star),
              icon: Icon(
                star <= (value ?? 0) ? Icons.star : Icons.star_border,
                color: star <= (value ?? 0)
                    ? AppColors.primaryDark
                    : AppColors.textSecondary,
              ),
            ),
        ],
      ),
      Text(value == null ? 'Chưa đánh giá' : labels[value! - 1]),
      if (value != null)
        TextButton(
          onPressed: () => onChanged(null),
          child: const Text('Bỏ đánh giá'),
        ),
    ],
  );
}
