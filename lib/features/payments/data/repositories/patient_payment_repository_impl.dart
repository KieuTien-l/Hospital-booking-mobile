import '../../domain/entities/patient_payment.dart';
import '../../domain/repositories/patient_payment_repository.dart';
import '../datasources/patient_payment_firebase_datasource.dart';

class PatientPaymentRepositoryImpl implements PatientPaymentRepository {
  PatientPaymentRepositoryImpl(this._datasource);

  final PatientPaymentFirebaseDatasource _datasource;

  @override
  Future<List<PatientPayment>> getPaymentsByPatient(String patientId) =>
      _datasource.getPaymentsByPatient(patientId);
}
