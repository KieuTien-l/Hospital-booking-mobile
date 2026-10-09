import 'package:flutter/material.dart';

import '../../../../core/themes/app_colors.dart';

class PatientProfileSectionTitle extends StatelessWidget {
  const PatientProfileSectionTitle({
    super.key,
    required this.title,
    required this.icon,
  });

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 20, color: AppColors.textOnPrimary),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          title,
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
    ],
  );
}
