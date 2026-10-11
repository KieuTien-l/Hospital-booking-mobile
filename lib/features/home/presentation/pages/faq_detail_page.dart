import 'package:flutter/material.dart';

import '../../../../core/themes/app_colors.dart';
import '../models/usage_guide_ui_model.dart';
import '../widgets/patient_home_background.dart';

class FaqDetailPage extends StatelessWidget {
  const FaqDetailPage({super.key, required this.faq});
  final FaqUiModel faq;
  @override
  Widget build(BuildContext context) => PatientHomeBackground(
    child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text(
          'Câu hỏi thường gặp',
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
                Align(
                  alignment: Alignment.centerLeft,
                  child: Chip(label: Text(faq.category.label)),
                ),
                const SizedBox(height: 12),
                Text(
                  faq.question,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textOnPrimary,
                  ),
                ),
                const SizedBox(height: 20),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      faq.answer,
                      style: Theme.of(context).textTheme.bodyLarge
                          ?.copyWith(height: 1.7),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Quay lại'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
