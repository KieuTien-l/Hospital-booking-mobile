import 'package:flutter/material.dart';

import '../models/payment_ui_model.dart';
import '../models/booking_review_ui_model.dart';
import '../widgets/payment_page_layout.dart';
import '../widgets/payment_status_badge.dart';
import 'payment_detail_page.dart';

class PaymentHistoryPage extends StatefulWidget {
  const PaymentHistoryPage({
    super.key,
    required this.transactions,
    this.isDemo = false,
  });
  final List<PaymentUiModel> transactions;
  final bool isDemo;
  @override
  State<PaymentHistoryPage> createState() => _PaymentHistoryPageState();
}

class _PaymentHistoryPageState extends State<PaymentHistoryPage> {
  PaymentStatus? _filter;
  @override
  Widget build(BuildContext context) {
    final items = widget.transactions
        .where((item) => _filter == null || item.status == _filter)
        .toList();
    return PaymentPageLayout(
      title: 'Thanh toán viện phí',
      isDemo: widget.isDemo,
      children: [
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Tất cả'),
              selected: _filter == null,
              onSelected: (_) => setState(() => _filter = null),
            ),
            for (final status in PaymentStatus.values)
              ChoiceChip(
                label: Text(status.label),
                selected: _filter == status,
                onSelected: (_) => setState(() => _filter = status),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (items.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Chưa có giao dịch thanh toán.',
              textAlign: TextAlign.center,
            ),
          ),
        for (final payment in items)
          Card(
            child: ListTile(
              title: Text(payment.transactionId ?? 'Chưa có mã giao dịch'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (payment.isDemo) const Text('Giao dịch minh họa'),
                  Text(bookingReviewTotalLabel(payment.items)),
                  PaymentStatusBadge(status: payment.status),
                ],
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) => PaymentDetailPage(payment: payment),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
