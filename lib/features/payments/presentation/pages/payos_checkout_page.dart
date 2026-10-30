import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../appointments/presentation/models/appointment_confirmation_ui_model.dart';
import '../../../appointments/presentation/pages/booking_success_page.dart';
import '../../../appointments/presentation/widgets/payment_page_layout.dart';
import '../../data/payos_payment_client.dart';

/// Patient checkout screen. PayOS hosts the actual banking/QR interaction;
/// this page creates the link, presents its QR payload and listens for the
/// server-confirmed result after PayOS sends its signed webhook.
class PayosCheckoutPage extends StatefulWidget {
  const PayosCheckoutPage({
    super.key,
    required this.appointmentId,
    required this.doctorName,
    required this.specialtyName,
  });

  final String appointmentId;
  final String doctorName;
  final String specialtyName;

  @override
  State<PayosCheckoutPage> createState() => _PayosCheckoutPageState();
}

class _PayosCheckoutPageState extends State<PayosCheckoutPage> {
  PayosPaymentClient? _client;
  PayosPaymentSession? _payment;
  String? _error;
  bool _working = false;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _paymentSubscription;
  bool _navigatedToSuccess = false;

  @override
  void initState() {
    super.initState();
    try {
      _client = PayosPaymentClient();
      WidgetsBinding.instance.addPostFrameCallback((_) => _create());
    } on PayosPaymentException catch (error) {
      _error = error.message;
    }
  }

  @override
  void dispose() {
    _paymentSubscription?.cancel();
    _client?.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final client = _client;
    if (client == null) return;
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      final payment = await client.create(appointmentId: widget.appointmentId);
      if (!mounted) return;
      setState(() => _payment = payment);
      _watchPayment(payment.id);
      if (payment.isPaid) _showBookingSuccess();
    } on PayosPaymentException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _refresh() async {
    final payment = _payment;
    final client = _client;
    if (payment == null || client == null) return;
    setState(() => _working = true);
    try {
      final refreshed = await client.status(payment.id);
      if (!mounted) return;
      setState(() => _payment = refreshed);
      if (refreshed.isPaid) _showBookingSuccess();
    } on PayosPaymentException catch (error) {
      if (mounted) _message(error.message);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  void _showBookingSuccess() {
    if (!mounted || _navigatedToSuccess) return;
    _navigatedToSuccess = true;
    _paymentSubscription?.cancel();
    Navigator.of(context).pushAndRemoveUntil<void>(
      MaterialPageRoute(builder: (_) => const BookingSuccessPage()),
      (route) => route.isFirst,
    );
  }

  void _watchPayment(String paymentId) {
    _paymentSubscription?.cancel();
    _paymentSubscription = FirebaseFirestore.instance
        .collection('THANH_TOAN')
        .doc(paymentId)
        .snapshots()
        .listen(
          (snapshot) {
            final status = snapshot.data()?['status']?.toString().toUpperCase();
            if (status == 'PAID') _showBookingSuccess();
          },
          // The manual refresh remains available if the device is temporarily
          // offline, but a valid webhook normally moves the patient forward
          // without any extra tap.
          onError: (error, stackTrace) {},
        );
  }

  Future<void> _openPayos() async {
    final checkoutUrl = _payment?.checkoutUrl;
    final uri = checkoutUrl == null ? null : Uri.tryParse(checkoutUrl);
    if (uri == null || uri.scheme != 'https') {
      _message('Liên kết PayOS chưa sẵn sàng. Vui lòng thử tạo lại.');
      return;
    }
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (mounted && !opened) {
      _message('Không thể mở trang PayOS trên thiết bị này.');
    }
  }

  Future<void> _cancel() async {
    final payment = _payment;
    final client = _client;
    if (payment == null || client == null) return;
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hủy liên kết thanh toán?'),
        content: const Text(
          'Bạn có thể tạo lại liên kết PayOS sau nếu chưa thanh toán.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Quay lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hủy liên kết'),
          ),
        ],
      ),
    );
    if (approved != true || !mounted) return;
    setState(() => _working = true);
    try {
      final cancelled = await client.cancel(payment.id);
      if (mounted) setState(() => _payment = cancelled);
    } on PayosPaymentException catch (error) {
      if (mounted) _message(error.message);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  void _message(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) {
    final payment = _payment;
    return PaymentPageLayout(
      title: 'Thanh toán PayOS',
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Thanh toán viện phí',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Text('Chuyên khoa: ${widget.specialtyName}'),
                Text('Bác sĩ: ${widget.doctorName}'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (_working && payment == null)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_error != null)
          _ErrorCard(message: _error!, onRetry: _working ? null : _create)
        else if (payment != null) ...[
          _PaymentCard(payment: payment),
          const SizedBox(height: 16),
          if (payment.qrCode != null && payment.isPending)
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
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
          if (payment.isPending && payment.checkoutUrl != null)
            FilledButton.icon(
              onPressed: _working ? null : _openPayos,
              icon: const Icon(Icons.open_in_new),
              label: const Text('Mở trang thanh toán PayOS'),
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _working ? null : _refresh,
            icon: _working
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            label: const Text('Kiểm tra trạng thái'),
          ),
          if (payment.canCancel) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _working ? null : _cancel,
              icon: const Icon(Icons.cancel_outlined),
              label: const Text('Hủy liên kết thanh toán'),
            ),
          ],
          if (payment.isPaid) ...[
            const SizedBox(height: 12),
            const Text(
              'PayOS đã xác nhận thanh toán thành công.',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.green,
              ),
            ),
          ],
        ],
      ],
    );
  }
}

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({required this.payment});
  final PayosPaymentSession payment;

  @override
  Widget build(BuildContext context) {
    final label = payment.isPaid
        ? 'Đã thanh toán'
        : payment.status == 'CANCELLED'
        ? 'Đã hủy'
        : payment.status == 'FAILED'
        ? 'Thanh toán thất bại'
        : 'Đang chờ thanh toán';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text('Số tiền: ${appointmentFeeLabel(payment.amount)}'),
            Text('Mã giao dịch: ${payment.id}'),
            if (payment.transactionCode != null)
              Text('Mã PayOS: ${payment.transactionCode}'),
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Thử lại'),
          ),
        ],
      ),
    ),
  );
}
