import 'package:flutter/material.dart';

class PaymentBottomActions extends StatelessWidget {
  const PaymentBottomActions({
    super.key,
    required this.total,
    required this.label,
    this.onPressed,
  });
  final String total;
  final String label;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Tổng thanh toán: $total',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: onPressed, child: Text(label)),
          ],
        ),
      ),
    ),
  );
}
