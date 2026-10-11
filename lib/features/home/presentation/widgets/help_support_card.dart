import 'package:flutter/material.dart';

import '../../../../core/themes/app_colors.dart';

class HelpSupportCard extends StatelessWidget {
  const HelpSupportCard({super.key});
  @override
  Widget build(BuildContext context) => Card(
    color: AppColors.primarySoft,
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.support_agent, color: AppColors.textOnPrimary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Cần hỗ trợ thêm?',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textOnPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text('Liên hệ bộ phận hỗ trợ của HealWay để được hướng dẫn.'),
          const SizedBox(height: 8),
          const Text(
            'Thông tin liên hệ đang được cập nhật',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          TextButton.icon(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Liên hệ HealWay'),
                content: const Text('Thông tin liên hệ đang được cập nhật'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Đã hiểu'),
                  ),
                ],
              ),
            ),
            icon: const Icon(Icons.contact_support_outlined),
            label: const Text('Liên hệ'),
          ),
        ],
      ),
    ),
  );
}
