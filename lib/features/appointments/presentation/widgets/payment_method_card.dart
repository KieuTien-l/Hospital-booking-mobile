import 'package:flutter/material.dart';

import '../../../../core/themes/app_colors.dart';
import '../models/payment_ui_model.dart';

class PaymentMethodCard extends StatelessWidget {
  const PaymentMethodCard({
    super.key,
    required this.method,
    required this.selected,
    required this.onTap,
  });
  final PaymentMethod method;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(
        color: selected ? AppColors.primaryDark : AppColors.divider,
        width: selected ? 2 : 1,
      ),
    ),
    child: Semantics(
      checked: selected,
      inMutuallyExclusiveGroup: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(switch (method) {
                PaymentMethod.momo => Icons.account_balance_wallet_outlined,
                PaymentMethod.bankTransfer => Icons.account_balance_outlined,
                PaymentMethod.bankQr => Icons.qr_code_2,
              }, color: AppColors.textOnPrimary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      method.label,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(method.description),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: selected
                    ? AppColors.primaryDark
                    : AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
