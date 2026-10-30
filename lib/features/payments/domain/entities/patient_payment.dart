class PatientPayment {
  const PatientPayment({
    required this.id,
    required this.patientId,
    required this.amount,
    required this.paymentMethod,
    required this.status,
    this.appointmentId,
    this.transactionCode,
    this.checkoutUrl,
    this.qrCode,
    this.createdAt,
    this.paidAt,
    this.isTestData = false,
  });

  final String id;
  final String patientId;
  final String? appointmentId;

  /// Null is deliberate: a malformed legacy transaction must be shown as
  /// incomplete, never silently converted to 0đ.
  final int? amount;
  final String paymentMethod;
  final String status;
  final String? transactionCode;
  final String? checkoutUrl;
  final String? qrCode;
  final DateTime? createdAt;
  final DateTime? paidAt;
  final bool isTestData;
}
