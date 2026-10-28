import 'package:flutter/material.dart';

import '../models/appointment_confirmation_ui_model.dart';
import '../models/booking_review_ui_model.dart';
import '../models/payment_ui_model.dart';
import '../widgets/booking_review_patient_card.dart';
import '../widgets/appointment_summary_card.dart';
import '../widgets/payment_bottom_actions.dart';
import '../widgets/payment_page_layout.dart';
import 'payment_method_page.dart';

/// Legacy preview-only payment page. Production payments start from an
/// appointment's "Thanh toán qua PayOS" action and never use this route.
@Deprecated('Use PayosCheckoutPage from AppointmentDetailPage.')
class PaymentInformationPage extends StatefulWidget {
  const PaymentInformationPage({
    super.key,
    required this.items,
    this.isDemo = false,
  });
  final List<AppointmentConfirmationResult> items;
  final bool isDemo;
  @override
  State<PaymentInformationPage> createState() => _PaymentInformationPageState();
}

class _PaymentInformationPageState extends State<PaymentInformationPage> {
  bool _expanded = true;
  @override
  Widget build(BuildContext context) => PaymentPageLayout(
    title: 'Thông tin thanh toán',
    isDemo: widget.isDemo,
    bottom: PaymentBottomActions(
      total: bookingReviewTotalLabel(widget.items),
      label: 'Chọn phương thức thanh toán',
      onPressed:
          paymentItemsHavePrice(widget.items) &&
              widget.items.every(bookingReviewItemIsValid)
          ? () => Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => PaymentMethodPage(
                  items: widget.items,
                  isDemo: widget.isDemo,
                ),
              ),
            )
          : null,
    ),
    children: [
      const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hướng dẫn thanh toán',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
              ),
              SizedBox(height: 12),
              Text(
                'Vui lòng kiểm tra thông tin đặt khám và lựa chọn phương thức thanh toán phù hợp.',
              ),
              SizedBox(height: 12),
              Text(
                'Vui lòng chờ hệ thống xác nhận kết quả thanh toán trước khi rời khỏi quy trình.',
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 16),
      BookingReviewPatientCard(
        information: widget.items.isEmpty
            ? null
            : widget.items.first.information,
        expanded: _expanded,
        onToggle: () => setState(() => _expanded = !_expanded),
      ),
      const SizedBox(height: 20),
      Text(
        'Chuyên khoa đã chọn (${widget.items.length})',
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
      ),
      if (widget.items.isEmpty) const Text('Chưa có chuyên khoa đã chọn.'),
      for (final item in widget.items)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppointmentSummaryCard(information: item.information),
              Text(
                'Tiền khám: ${item.information.fee == null || item.information.fee! < 0 ? "Chưa có thông tin giá" : appointmentFeeLabel(item.information.fee)}${item.information.isDemoFee ? " (Giá minh họa)" : ""}',
                textAlign: TextAlign.end,
              ),
            ],
          ),
        ),
    ],
  );
}
