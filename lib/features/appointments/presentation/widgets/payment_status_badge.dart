import 'package:flutter/material.dart';

import '../../../../core/themes/app_colors.dart';
import '../models/payment_ui_model.dart';

class PaymentStatusBadge extends StatelessWidget {
  const PaymentStatusBadge({super.key, required this.status});
  final PaymentStatus status;
  @override
  Widget build(BuildContext context) => Chip(
    avatar: Icon(
      switch (status) {
        PaymentStatus.pending => Icons.schedule,
        PaymentStatus.success => Icons.check_circle_outline,
        PaymentStatus.failed => Icons.error_outline,
      },
      color: status == PaymentStatus.failed
          ? AppColors.error
          : AppColors.textOnPrimary,
    ),
    label: Text(status.label),
  );
}
