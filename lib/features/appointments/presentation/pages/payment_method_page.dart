import 'package:flutter/material.dart';

import '../models/appointment_confirmation_ui_model.dart';
import '../models/booking_review_ui_model.dart';
import '../models/payment_ui_model.dart';
import '../widgets/payment_page_layout.dart';
import '../widgets/payment_method_card.dart';
import '../widgets/payment_bottom_actions.dart';
import 'payment_processing_page.dart';

class PaymentMethodPage extends StatefulWidget {
  const PaymentMethodPage({
    super.key,
    required this.items,
    this.isDemo = false,
  });
  final List<AppointmentConfirmationResult> items;
  final bool isDemo;
  @override
  State<PaymentMethodPage> createState() => _PaymentMethodPageState();
}

class _PaymentMethodPageState extends State<PaymentMethodPage> {
  PaymentMethod? _method;
  @override
  Widget build(BuildContext context) => PaymentPageLayout(
    title: 'Phương thức thanh toán',
    isDemo: widget.isDemo,
    bottom: PaymentBottomActions(
      total: bookingReviewTotalLabel(widget.items),
      label: 'Tiếp tục thanh toán',
      onPressed: _method == null || !paymentItemsHavePrice(widget.items)
          ? null
          : () => Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => PaymentProcessingPage(
                  items: widget.items,
                  method: _method!,
                  isDemo: widget.isDemo,
                ),
              ),
            ),
    ),
    children: [
      for (final method in PaymentMethod.values)
        PaymentMethodCard(
          method: method,
          selected: method == _method,
          onTap: () => setState(() => _method = method),
        ),
    ],
  );
}
