import 'package:flutter/material.dart';

import '../../../../core/themes/app_colors.dart';

class HelpTopicCard extends StatelessWidget {
  const HelpTopicCard({
    super.key,
    required this.title,
    required this.icon,
    required this.onTap,
    this.description,
  });
  final String title;
  final IconData icon;
  final String? description;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppColors.primarySoft,
              child: Icon(icon, color: AppColors.textOnPrimary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  if (description != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      description!,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ],
        ),
      ),
    ),
  );
}
