import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

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

  Future<void> _openPayos() async {
    final uri = Uri.tryParse(payment.checkoutUrl ?? '');
    if (uri == null || uri.scheme != 'https') return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) => PaymentPageLayout(
    title: 'Chi tiết thanh toán',
    isDemo: payment.isDemo,
    children: [
      PaymentSummaryCard(payment: payment),
      if (payment.status == PaymentStatus.pending &&
          payment.qrCode?.trim().isNotEmpty == true) ...[
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Text(
                  'Quét QR bằng ứng dụng ngân hàng',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                QrImageView(
                  data: payment.qrCode!,
                  size: 220,
                  errorCorrectionLevel: QrErrorCorrectLevel.M,
                ),
                if (payment.checkoutUrl?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _openPayos,
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Mở trang thanh toán PayOS'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
      if (payment.items.isNotEmpty)
        BookingReviewPatientCard(
          information: payment.items.first.information,
          expanded: _expanded,
          onToggle: () => setState(() => _expanded = !_expanded),
        ),
      for (final item in payment.items)
        AppointmentSummaryCard(information: item.information),
      if (payment.status == PaymentStatus.success)
        FilledButton(
          onPressed: () => Navigator.of(context).push<void>(
            MaterialPageRoute(
              builder: (_) => PaymentReceiptPage(payment: payment),
            ),
          ),
          child: Text(payment.isDemo ? 'Xem biên lai mẫu' : 'Xem biên lai'),
        ),
    ],
  );
}
