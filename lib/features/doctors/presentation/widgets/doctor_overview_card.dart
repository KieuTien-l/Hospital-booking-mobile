import 'package:flutter/material.dart';

import '../../../../core/themes/app_colors.dart';
import '../models/doctor_detail_ui_model.dart';

class DoctorOverviewCard extends StatelessWidget {
  const DoctorOverviewCard({super.key, required this.doctor});
  final DoctorDetailUiModel doctor;

  @override
  Widget build(BuildContext context) {
    const placeholder = Icon(
      Icons.person_outline,
      size: 60,
      color: AppColors.textOnPrimary,
    );
    final portrait = Container(
      width: 100,
      height: 120,
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: doctor.avatarUrl?.isNotEmpty == true
          ? Image.network(
              doctor.avatarUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => placeholder,
            )
          : placeholder,
    );
    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            doctor.name,
            maxLines: 1,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.textOnPrimary,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DoctorInfoBadge(
              icon: Icons.medical_services_outlined,
              label: doctor.specialty,
            ),
            if (doctor.gender?.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              _DoctorInfoBadge(
                icon: Icons.person_outline,
                label: doctor.gender!,
              ),
            ],
          ],
        ),
      ],
    );
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 330 ||
                    MediaQuery.textScalerOf(context).scale(16) > 20) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [portrait, const SizedBox(height: 16), info],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    portrait,
                    const SizedBox(width: 16),
                    Expanded(child: info),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DoctorInfoBadge extends StatelessWidget {
  const _DoctorInfoBadge({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: AppColors.primarySoft,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: AppColors.primaryDark),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ],
    ),
  );
}
