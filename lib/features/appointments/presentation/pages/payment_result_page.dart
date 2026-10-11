import 'package:flutter/material.dart';

import '../models/payment_ui_model.dart';
import '../widgets/payment_page_layout.dart';
import '../widgets/payment_summary_card.dart';
import 'booking_success_page.dart';
import 'payment_method_page.dart';

class PaymentResultPage extends StatelessWidget {
  const PaymentResultPage({super.key, required this.payment});
  final PaymentUiModel payment;
  @override
  Widget build(BuildContext context) => PaymentPageLayout(
    title: 'Kết quả thanh toán',
    isDemo: payment.isDemo,
    children: [
      PaymentSummaryCard(payment: payment),
      const SizedBox(height: 16),
      if (payment.status == PaymentStatus.pending)
        const Text('Đang chờ xác nhận. Trạng thái không tự chuyển thành công.'),
      if (payment.status == PaymentStatus.success && payment.isDemo)
        FilledButton(
          onPressed: () => Navigator.of(context).push<void>(
            MaterialPageRoute(
              builder: (_) => BookingSuccessPage(payment: payment),
            ),
          ),
          child: const Text('Xem đặt khám thành công (demo)'),
        ),
      if (payment.status == PaymentStatus.failed) ...[
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Thử lại'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pushReplacement<void, void>(
            MaterialPageRoute(
              builder: (_) => PaymentMethodPage(
                items: payment.items,
                isDemo: payment.isDemo,
              ),
            ),
          ),
          child: const Text('Chọn phương thức khác'),
        ),
      ],
    ],
  );
}
