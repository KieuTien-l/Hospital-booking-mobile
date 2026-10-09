import 'package:flutter/material.dart';

import '../../../../core/themes/app_colors.dart';

class DoctorDetailSection extends StatelessWidget {
  const DoctorDetailSection({
    super.key,
    required this.title,
    required this.child,
    this.initiallyExpanded = false,
  });
  final String title;
  final Widget child;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    clipBehavior: Clip.antiAlias,
    child: ExpansionTile(
      key: PageStorageKey(title),
      initiallyExpanded: initiallyExpanded,
      maintainState: true,
      tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
      shape: const Border(),
      collapsedShape: const Border(),
      iconColor: AppColors.textOnPrimary,
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          color: AppColors.textOnPrimary,
        ),
      ),
      children: [SizedBox(width: double.infinity, child: child)],
    ),
  );
}
