import 'appointment_confirmation_ui_model.dart';

enum PaymentMethod { momo, bankTransfer, bankQr }

enum PaymentStatus { pending, success, failed }

extension PaymentMethodLabel on PaymentMethod {
  String get label => switch (this) {
    PaymentMethod.momo => 'Ví điện tử MoMo',
    PaymentMethod.bankTransfer => 'Chuyển khoản ngân hàng',
    PaymentMethod.bankQr => 'Quét mã QR',
  };
  String get description => switch (this) {
    PaymentMethod.momo => 'Thanh toán qua ví điện tử MoMo.',
    PaymentMethod.bankTransfer => 'Thanh toán qua ứng dụng ngân hàng.',
    PaymentMethod.bankQr => 'Dùng ứng dụng ngân hàng hỗ trợ quét mã.',
  };
}

extension PaymentStatusLabel on PaymentStatus {
  String get label => switch (this) {
    PaymentStatus.pending => 'Chờ xác nhận',
    PaymentStatus.success => 'Thanh toán thành công',
    PaymentStatus.failed => 'Thanh toán thất bại',
  };
}

PaymentMethod paymentMethodFromValue(String? value) {
  switch ((value ?? '').trim().toUpperCase()) {
    case 'MOMO':
      return PaymentMethod.momo;
    case 'BANK_QR':
    case 'BANKQR':
    case 'QR':
      return PaymentMethod.bankQr;
    case 'VNPAY':
    case 'BANK_TRANSFER':
    case 'BANKTRANSFER':
    default:
      return PaymentMethod.bankTransfer;
  }
}

PaymentStatus paymentStatusFromValue(String? value) {
  switch ((value ?? '').trim().toUpperCase()) {
    case 'SUCCESS':
    case 'PAID':
    case 'COMPLETED':
      return PaymentStatus.success;
    case 'FAILED':
    case 'FAIL':
    case 'CANCELLED':
    case 'CANCELED':
      return PaymentStatus.failed;
    default:
      return PaymentStatus.pending;
  }
}

/// Presentation snapshot of a payment record.
class PaymentUiModel {
  PaymentUiModel({
    required List<AppointmentConfirmationResult> items,
    required this.method,
    required this.status,
    this.transactionId,
    this.timestamp,
    this.amount,
    this.appointmentId,
    this.isTestData = false,
    this.isDemo = false,
  }) : items = List.unmodifiable(items);
  final List<AppointmentConfirmationResult> items;
  final PaymentMethod method;
  final PaymentStatus status;
  final String? transactionId;
  final DateTime? timestamp;
  final int? amount;
  final String? appointmentId;
  final bool isTestData;
  final bool isDemo;
}

int? paymentTotalAmount(PaymentUiModel payment) {
  if (payment.amount != null && payment.amount! >= 0) return payment.amount;
  if (!paymentItemsHavePrice(payment.items)) return null;
  return payment.items.fold<int>(0, (sum, item) => sum + item.information.fee!);
}

String paymentTotalLabel(PaymentUiModel payment) =>
    appointmentFeeLabel(paymentTotalAmount(payment));

bool paymentItemsHavePrice(List<AppointmentConfirmationResult> items) =>
    items.isNotEmpty &&
    items.every(
      (item) => item.information.fee != null && item.information.fee! >= 0,
    );
