import 'package:flutter/material.dart';

import '../models/payment_ui_model.dart';
import '../models/booking_review_ui_model.dart';
import '../models/appointment_time_ui_models.dart';
import 'payment_status_badge.dart';

class PaymentSummaryCard extends StatelessWidget {
  const PaymentSummaryCard({super.key, required this.payment});
  final PaymentUiModel payment;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PaymentStatusBadge(status: payment.status),
          const SizedBox(height: 12),
          Text(
            bookingReviewTotalLabel(payment.items),
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Text('Phương thức: ${payment.method.label}'),
          Text('Mã giao dịch: ${payment.transactionId ?? "Chưa có"}'),
          Text(
            'Thời gian: ${payment.timestamp == null ? "Chưa có" : "${appointmentDateLabel(payment.timestamp!)} ${payment.timestamp!.hour.toString().padLeft(2, '0')}:${payment.timestamp!.minute.toString().padLeft(2, '0')}"}',
          ),
        ],
      ),
    ),
  );
}
