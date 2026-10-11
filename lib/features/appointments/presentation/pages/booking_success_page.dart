import 'package:flutter/material.dart';

import '../models/payment_ui_model.dart';
import '../widgets/payment_page_layout.dart';
import '../widgets/appointment_summary_card.dart';
import '../widgets/booking_review_patient_card.dart';

class BookingSuccessPage extends StatefulWidget {
  const BookingSuccessPage({super.key, required this.payment});
  final PaymentUiModel payment;
  @override
  State<BookingSuccessPage> createState() => _BookingSuccessPageState();
}

class _BookingSuccessPageState extends State<BookingSuccessPage> {
  bool _expanded = true;
  PaymentUiModel get payment => widget.payment;
  @override
  Widget build(BuildContext context) => PaymentPageLayout(
    title: 'Hoàn tất đặt khám',
    isDemo: payment.isDemo,
    children: payment.status != PaymentStatus.success || !payment.isDemo
        ? [const Text('Chưa có xác nhận đặt khám.')]
        : [
            const Icon(Icons.check_circle_outline, size: 72),
            const Text(
              'Đặt khám thành công (demo)',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 22),
            ),
            const SizedBox(height: 12),
            const Text('Phiếu minh họa. Chưa tạo lịch hẹn thật.'),
            if (payment.items.isNotEmpty)
              BookingReviewPatientCard(
                information: payment.items.first.information,
                expanded: _expanded,
                onToggle: () => setState(() => _expanded = !_expanded),
              ),
            for (final item in payment.items)
              AppointmentSummaryCard(information: item.information),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).popUntil((route) => route.isFirst),
              child: const Text('Về trang chủ'),
            ),
          ],
  );
}
