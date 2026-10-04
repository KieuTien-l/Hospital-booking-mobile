import 'package:flutter/material.dart';

import '../../../../core/themes/app_colors.dart';
import '../models/patient_function.dart';

/// Body of the patient Functions tab. Navigation belongs to PatientHomePage.
class FunctionsPage extends StatelessWidget {
  const FunctionsPage({super.key, required this.onOpen});

  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Colors.white,
    child: SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Text(
              'Chức năng',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontSize: 24,
                color: const Color(0xFF1B2B38),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: ColoredBox(
              color: const Color(0xFFF6F7F9),
              child: SingleChildScrollView(
                key: const PageStorageKey('patient-functions'),
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _group(context, 'Tiện ích khám bệnh', 0, 5),
                    const SizedBox(height: 28),
                    _group(context, 'Hỗ trợ & Tiện ích', 5, 8),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _group(BuildContext context, String title, int start, int end) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: AppColors.textOnPrimary.withValues(alpha: .04),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (var index = start; index < end; index++) ...[
                    if (index != start)
                      const Divider(height: 1, indent: 72, endIndent: 16),
                    _item(context, index),
                  ],
                ],
              ),
            ),
          ),
        ],
      );

  Widget _item(BuildContext context, int index) {
    final feature = patientFunctions[index];
    final title = feature.$1.replaceFirst(' (Chatbot)', '');
    return InkWell(
      onTap: () => onOpen(feature.$1),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                patientFunctionListIcons[index],
                color: const Color(0xFF2583E3),
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondary,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}
