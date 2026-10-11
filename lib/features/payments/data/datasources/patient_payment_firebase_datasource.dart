import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/patient_payment_model.dart';

class PatientPaymentFirebaseDatasource {
  PatientPaymentFirebaseDatasource(this._firestore);

  final FirebaseFirestore _firestore;

  Future<List<PatientPaymentModel>> getPaymentsByPatient(
    String patientId,
  ) async {
    final normalizedPatientId = patientId.trim();
    if (normalizedPatientId.isEmpty) return const [];

    final query = await _firestore
        .collection(PatientPaymentModel.collectionName)
        .where('patientId', isEqualTo: normalizedPatientId)
        .get();
    final payments = query.docs
        .map(PatientPaymentModel.fromFirestore)
        .toList();
    payments.sort((left, right) {
      final leftDate = left.paidAt ?? left.createdAt;
      final rightDate = right.paidAt ?? right.createdAt;
      return (rightDate ?? DateTime(0)).compareTo(leftDate ?? DateTime(0));
    });
    return payments;
  }
}
