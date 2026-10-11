import 'package:flutter/material.dart';

import '../../../../core/themes/app_colors.dart';
import '../pages/patient_support_page.dart';

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
          TextButton.icon(
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => const PatientSupportPage(
                  kind: PatientSupportKind.contact,
                ),
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
