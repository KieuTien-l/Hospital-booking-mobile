import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/utils/model_value_parser.dart';
import '../../domain/entities/patient_payment.dart';

class PatientPaymentModel extends PatientPayment {
  const PatientPaymentModel({
    required super.id,
    required super.patientId,
    required super.amount,
    required super.paymentMethod,
    required super.status,
    super.appointmentId,
    super.transactionCode,
    super.checkoutUrl,
    super.qrCode,
    super.createdAt,
    super.paidAt,
    super.isTestData,
  });

  static const collectionName = 'THANH_TOAN';

  factory PatientPaymentModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) =>
      PatientPaymentModel.fromMap(document.data() ?? const {}, id: document.id);

  factory PatientPaymentModel.fromMap(
    Map<String, dynamic> data, {
    required String id,
  }) => PatientPaymentModel(
    id: id,
    // Data migration writes only the canonical English schema. Keeping a
    // legacy fallback here would silently mask an incomplete migration and
    // would make the payment access rule impossible to reason about.
    patientId: readReferenceId(data['patientId']),
    appointmentId: readOptionalString(data['appointmentId']),
    amount: _readAmount(data['amount']),
    paymentMethod: readString(data['paymentMethod'], fallback: 'BANK_TRANSFER'),
    status: readString(data['status'], fallback: 'PENDING'),
    transactionCode: readOptionalString(data['transactionCode']),
    checkoutUrl: readOptionalString(data['checkoutUrl']),
    qrCode: readOptionalString(data['qrCode']),
    createdAt: readDateTime(data['createdAt']),
    paidAt: readDateTime(data['paidAt']),
    isTestData: readBool(data['isTestData']),
  );

  static int? _readAmount(Object? value) {
    if (value is int && value >= 0) return value;
    if (value is double &&
        value.isFinite &&
        value >= 0 &&
        value == value.roundToDouble()) {
      return value.toInt();
    }
    return null;
  }
}
