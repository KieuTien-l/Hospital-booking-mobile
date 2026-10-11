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

/// Presentation snapshot only. Never verifies or persists a transaction.
class PaymentUiModel {
  PaymentUiModel({
    required List<AppointmentConfirmationResult> items,
    required this.method,
    required this.status,
    this.transactionId,
    this.timestamp,
    this.isDemo = false,
  }) : items = List.unmodifiable(items);
  final List<AppointmentConfirmationResult> items;
  final PaymentMethod method;
  final PaymentStatus status;
  final String? transactionId;
  final DateTime? timestamp;
  final bool isDemo;
}

bool paymentItemsHavePrice(List<AppointmentConfirmationResult> items) =>
    items.isNotEmpty &&
    items.every(
      (item) => item.information.fee != null && item.information.fee! >= 0,
    );
