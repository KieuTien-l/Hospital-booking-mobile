import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../payments/domain/entities/patient_payment.dart';
import '../../../payments/presentation/controllers/patient_payment_controller.dart';
import '../../../profile/presentation/controllers/patient_profile_controller.dart';
import '../models/payment_ui_model.dart';
import '../widgets/payment_page_layout.dart';
import '../widgets/payment_status_badge.dart';
import 'payment_detail_page.dart';

/// Displays either injected preview payments or the signed-in patient's real
/// records from the `THANH_TOAN` collection.
class PaymentHistoryPage extends StatefulWidget {
  const PaymentHistoryPage({super.key, this.transactions, this.isDemo = false});

  final List<PaymentUiModel>? transactions;
  final bool isDemo;

  @override
  State<PaymentHistoryPage> createState() => _PaymentHistoryPageState();
}

class _PaymentHistoryPageState extends State<PaymentHistoryPage> {
  PaymentStatus? _filter;
  String? _loadedPatientId;

  @override
  void initState() {
    super.initState();
    if (widget.transactions == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadPayments());
    }
  }

  void _loadPayments({bool force = false}) {
    if (!mounted || widget.transactions != null) return;
    final patient = context.read<PatientProfileController?>()?.patient;
    final controller = context.read<PatientPaymentController?>();
    if (patient == null ||
        controller == null ||
        (!force && _loadedPatientId == patient.id)) {
      return;
    }
    _loadedPatientId = patient.id;
    controller.loadPayments(patient.id);
  }

  PaymentUiModel _toUiModel(PatientPayment payment) => PaymentUiModel(
    items: const [],
    method: paymentMethodFromValue(payment.paymentMethod),
    status: paymentStatusFromValue(payment.status),
    transactionId: payment.transactionCode?.trim().isNotEmpty == true
        ? payment.transactionCode
        : payment.id,
    checkoutUrl: payment.checkoutUrl,
    qrCode: payment.qrCode,
    timestamp: payment.paidAt ?? payment.createdAt,
    amount: payment.amount,
    appointmentId: payment.appointmentId,
    isTestData: payment.isTestData,
  );

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<PatientProfileController?>();
    final patient = profile?.patient;
    final controller = context.watch<PatientPaymentController?>();
    if (widget.transactions == null &&
        patient != null &&
        _loadedPatientId != patient.id) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadPayments());
    }

    final source =
        widget.transactions ??
        (controller?.payments.map(_toUiModel).toList() ?? const []);
    final payments = source
        .where((payment) => _filter == null || payment.status == _filter)
        .toList();
    final loading =
        widget.transactions == null && controller?.isLoading == true;
    final hasError = widget.transactions == null && controller?.isError == true;
    final needsProfile =
        widget.transactions == null && profile != null && patient == null;

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
        if (needsProfile)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Vui lòng cập nhật hồ sơ bệnh nhân để xem thanh toán viện phí.',
              textAlign: TextAlign.center,
            ),
          )
        else if (loading)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (hasError)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Text(
                  controller?.errorMessage ??
                      'Không thể tải giao dịch thanh toán.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => _loadPayments(force: true),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Thử lại'),
                ),
              ],
            ),
          )
        else if (payments.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Chưa có giao dịch thanh toán.',
              textAlign: TextAlign.center,
            ),
          )
        else
          for (final payment in payments)
            Card(
              child: ListTile(
                title: Text(payment.transactionId ?? 'Chưa có mã giao dịch'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (payment.isDemo) const Text('Giao dịch minh họa'),
                    if (payment.isTestData) const Text('Dữ liệu kiểm thử'),
                    Text(paymentTotalLabel(payment)),
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
