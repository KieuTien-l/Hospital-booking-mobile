import 'package:flutter/material.dart';

import '../models/payment_ui_model.dart';
import '../widgets/payment_page_layout.dart';
import '../widgets/payment_summary_card.dart';
import '../widgets/booking_review_patient_card.dart';
import '../widgets/appointment_summary_card.dart';
import 'payment_receipt_page.dart';

class PaymentDetailPage extends StatefulWidget {
  const PaymentDetailPage({super.key, required this.payment});
  final PaymentUiModel payment;
  @override
  State<PaymentDetailPage> createState() => _PaymentDetailPageState();
}

class _PaymentDetailPageState extends State<PaymentDetailPage> {
  bool _expanded = true;
  PaymentUiModel get payment => widget.payment;
  @override
  Widget build(BuildContext context) => PaymentPageLayout(
    title: 'Chi tiết thanh toán',
    isDemo: payment.isDemo,
    children: [
      PaymentSummaryCard(payment: payment),
      BookingReviewPatientCard(
        information: payment.items.isEmpty
            ? null
            : payment.items.first.information,
        expanded: _expanded,
        onToggle: () => setState(() => _expanded = !_expanded),
      ),
      for (final item in payment.items)
        AppointmentSummaryCard(information: item.information),
      if (payment.status == PaymentStatus.success && payment.isDemo)
        FilledButton(
          onPressed: () => Navigator.of(context).push<void>(
            MaterialPageRoute(
              builder: (_) => PaymentReceiptPage(payment: payment),
            ),
          ),
          child: const Text('Xem biên lai mẫu'),
        ),
    ],
  );
}
