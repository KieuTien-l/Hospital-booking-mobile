import 'package:flutter/material.dart';

import '../models/payment_ui_model.dart';
import '../widgets/payment_page_layout.dart';
import '../widgets/payment_summary_card.dart';
import '../widgets/appointment_summary_card.dart';

class PaymentReceiptPage extends StatelessWidget {
  const PaymentReceiptPage({super.key, required this.payment});
  final PaymentUiModel payment;
  @override
  Widget build(BuildContext context) => PaymentPageLayout(
    title: 'Biên lai mẫu',
    isDemo: payment.isDemo,
    children: payment.isDemo && payment.status == PaymentStatus.success
        ? [
            const Text(
              'MẪU MINH HỌA • KHÔNG CÓ GIÁ TRỊ THANH TOÁN',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            PaymentSummaryCard(payment: payment),
            if (payment.items.isNotEmpty)
              Text(
                'Người bệnh: ${payment.items.first.information.patient?.fullName ?? payment.items.first.information.patientName ?? "Chưa có thông tin"}',
              ),
            if (payment.items.isNotEmpty &&
                payment.items.first.information.patient != null)
              Text('Mã hồ sơ: ${payment.items.first.information.patient!.id}'),
            for (final item in payment.items)
              AppointmentSummaryCard(information: item.information),
            const Text(
              'Biên lai chính thức sẽ được cung cấp sau khi tích hợp hệ thống thanh toán.',
            ),
          ]
        : [const Text('Chưa có biên lai được xác nhận.')],
  );
}
