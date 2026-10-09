import 'package:flutter/material.dart';

import '../../../../core/themes/app_colors.dart';
import '../models/appointment_confirmation_ui_model.dart';

class AppointmentConfirmationActions extends StatelessWidget {
  const AppointmentConfirmationActions({
    super.key,
    required this.information,
    required this.onAddSpecialty,
    required this.onContinue,
  });
  final AppointmentConfirmationUiModel information;
  final VoidCallback onAddSpecialty;
  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 16,
            runSpacing: 4,
            children: [
              const Text(
                'Tiền khám',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              Text(
                appointmentFeeLabel(information.fee),
                style: const TextStyle(
                  color: AppColors.textOnPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 24,
                ),
              ),
            ],
          ),
          if (information.isDemoFee && information.fee != null)
            const Text(
              'Giá minh họa',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final add = OutlinedButton.icon(
                onPressed: onAddSpecialty,
                icon: const Icon(Icons.medical_services_outlined, size: 20),
                label: const Text('Thêm chuyên khoa'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 52),
                  foregroundColor: AppColors.primaryDark,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
              final next = ElevatedButton(
                key: const ValueKey('continue-confirmation'),
                onPressed: onContinue,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryDark,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Tiếp tục'),
              );
              if (constraints.maxWidth < 440 ||
                  MediaQuery.textScalerOf(context).scale(16) > 20) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [add, const SizedBox(height: 10), next],
                );
              }
              return Row(
                children: [
                  Expanded(child: add),
                  const SizedBox(width: 12),
                  Expanded(child: next),
                ],
              );
            },
          ),
        ],
      ),
    ),
  );
}
