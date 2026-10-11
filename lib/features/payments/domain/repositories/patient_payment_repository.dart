import '../entities/patient_payment.dart';

abstract class PatientPaymentRepository {
  Future<List<PatientPayment>> getPaymentsByPatient(String patientId);
}
