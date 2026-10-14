import 'package:flutter/material.dart';

import '../../../../core/themes/app_colors.dart';

class DoctorDetailSection extends StatelessWidget {
  const DoctorDetailSection({
    super.key,
    required this.title,
    required this.child,
    this.initiallyExpanded = false,
    this.icon,
    this.subtitle,
    this.titleColor,
  });
  final String title;
  final Widget child;
  final bool initiallyExpanded;
  final IconData? icon;
  final String? subtitle;
  final Color? titleColor;

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
      leading: icon == null ? null : Icon(icon, color: AppColors.textOnPrimary),
      subtitle: subtitle == null
          ? null
          : Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 4),
              child: Text(
                subtitle!,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
            ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: titleColor ?? AppColors.textOnPrimary,
        ),
      ),
      children: [SizedBox(width: double.infinity, child: child)],
    ),
  );
}
