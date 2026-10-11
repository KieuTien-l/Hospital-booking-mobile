import 'package:flutter/material.dart';

import '../../../../core/themes/app_colors.dart';
import '../models/usage_guide_ui_model.dart';
import '../widgets/patient_home_background.dart';

class UsageGuideDetailPage extends StatelessWidget {
  const UsageGuideDetailPage({super.key, required this.guide});
  final UsageGuideUiModel guide;
  @override
  Widget build(BuildContext context) => PatientHomeBackground(
    child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text(
          'Chi tiết hướng dẫn',
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
                Text(
                  guide.title,
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Text(guide.description),
                const SizedBox(height: 20),
                for (var i = 0; i < guide.steps.length; i++)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            backgroundColor: AppColors.primarySoft,
                            foregroundColor: AppColors.textOnPrimary,
                            child: Text(
                              '${i + 1}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              guide.steps[i],
                              style: const TextStyle(height: 1.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Đã hiểu'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
