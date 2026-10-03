import '../../domain/entities/patient.dart';
import '../../domain/repositories/patient_repository.dart';
import '../datasources/patient_firebase_datasource.dart';

class PatientRepositoryImpl implements PatientRepository {
  PatientRepositoryImpl(PatientFirebaseDatasource datasource)
    : _datasource = datasource;

  final PatientFirebaseDatasource _datasource;

  @override
  Stream<Patient?> watchPatientByAuthUser(String authUserId) =>
      _datasource.watchPatientByAuthUser(authUserId);

  @override
  Future<Patient?> getPatientById(String patientId) =>
      _datasource.getPatientById(patientId);

  @override
  Future<Patient> createPatient(Patient patient) =>
      _datasource.createPatient(patient);

  @override
  Future<Patient> updatePatient(Patient patient) =>
      _datasource.updatePatient(patient);
}
