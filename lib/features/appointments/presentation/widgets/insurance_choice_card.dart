import 'package:flutter/material.dart';

import '../../../../core/themes/app_colors.dart';

class InsuranceChoiceCard extends StatelessWidget {
  const InsuranceChoiceCard({
    super.key,
    required this.title,
    required this.groupId,
    required this.value,
    required this.onChanged,
    this.description,
  });
  final String title;
  final String groupId;
  final String? description;
  final bool? value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: title),
                const TextSpan(
                  text: ' *',
                  style: TextStyle(color: AppColors.error),
                ),
              ],
            ),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          if (description != null) ...[
            const SizedBox(height: 4),
            Text(
              description!,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              for (final option in [true, false]) ...[
                if (!option) const SizedBox(width: 12),
                Expanded(
                  child: Semantics(
                    checked: value == option,
                    inMutuallyExclusiveGroup: true,
                    child: OutlinedButton(
                      key: ValueKey('$groupId-${option ? 'yes' : 'no'}'),
                      onPressed: () => onChanged(option),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 12,
                        ),
                        backgroundColor: value == option
                            ? AppColors.primaryLight
                            : AppColors.surface,
                        foregroundColor: value == option
                            ? AppColors.textOnPrimary
                            : AppColors.textSecondary,
                        side: BorderSide(
                          color: value == option
                              ? AppColors.primaryDark
                              : AppColors.border,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            value == option
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Flexible(child: Text(option ? 'Có' : 'Không')),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    ),
  );
}
