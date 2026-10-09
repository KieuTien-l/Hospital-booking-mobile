import 'package:flutter/material.dart';

import '../../../../core/themes/app_colors.dart';
import '../../domain/entities/patient.dart';

class PatientProfileCard extends StatelessWidget {
  const PatientProfileCard({
    super.key,
    required this.patient,
    required this.onTap,
  });

  final Patient patient;
  final VoidCallback onTap;

  String get _maskedPhone {
    final phone = patient.phone.replaceAll(RegExp(r'\s'), '');
    if (phone.isEmpty) return 'Chưa có số điện thoại';
    if (phone.length <= 6) return List.filled(phone.length, '*').join();
    return '${phone.substring(0, 3)}${List.filled(phone.length - 6, '*').join()}${phone.substring(phone.length - 3)}';
  }

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: AppColors.primarySoft,
                  child: Icon(
                    Icons.person_outline,
                    color: AppColors.textOnPrimary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    patient.fullName.toUpperCase(),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.textOnPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.textSecondary),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: Card(
                margin: EdgeInsets.zero,
                color: AppColors.primarySoft,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: 10,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              patient.id,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            Text(
                              _maskedPhone,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 120),
                        child: Chip(
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          labelPadding: const EdgeInsets.symmetric(
                            horizontal: 6,
                          ),
                          avatar: const Icon(
                            Icons.account_circle_outlined,
                            size: 16,
                            color: AppColors.textOnPrimary,
                          ),
                          label: Text(
                            patient.relationshipToAccountHolder ??
                                'Chưa xác định',
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppColors.textOnPrimary),
                          ),
                          backgroundColor: AppColors.surface,
                          side: const BorderSide(color: AppColors.border),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
