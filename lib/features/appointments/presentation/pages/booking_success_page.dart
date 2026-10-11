import 'package:flutter/material.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../home/presentation/widgets/patient_home_background.dart';
import '../models/payment_ui_model.dart';
import '../widgets/appointment_summary_card.dart';
import '../widgets/booking_review_patient_card.dart';
import '../widgets/payment_page_layout.dart';

/// Shown after either a committed booking or the payment-flow demonstration.
///
/// A real booking always uses the default success state. [payment] is only
/// supplied by the payment UI demonstration, which must never imply that it
/// created an appointment in Firestore.
class BookingSuccessPage extends StatefulWidget {
  const BookingSuccessPage({super.key, this.payment});

  final PaymentUiModel? payment;

  @override
  State<BookingSuccessPage> createState() => _BookingSuccessPageState();
}

class _BookingSuccessPageState extends State<BookingSuccessPage> {
  bool _expanded = true;

  void _goHome() => Navigator.of(context).popUntil((route) => route.isFirst);

  @override
  Widget build(BuildContext context) {
    final payment = widget.payment;
    if (payment != null) {
      return PaymentPageLayout(
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
                  onPressed: _goHome,
                  child: const Text('Về trang chủ'),
                ),
              ],
      );
    }

    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: Theme.of(context).textTheme.apply(fontFamily: 'BeVietnamPro'),
      ),
      child: PatientHomeBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Card(
                    elevation: 0,
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                      side: const BorderSide(color: AppColors.border),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 88,
                            height: 88,
                            decoration: const BoxDecoration(
                              color: Color(0xFFDCFCE7),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check_circle_rounded,
                              color: AppColors.success,
                              size: 56,
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'Đặt lịch thành công',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Lịch hẹn của bạn đã được ghi nhận. Bạn có thể xem lại tại mục Lịch hẹn.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 28),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              key: const ValueKey('booking-success-home'),
                              onPressed: _goHome,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryDark,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 15),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Về trang chủ',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
