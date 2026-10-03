import '../entities/patient.dart';

/// Creates, reads and updates patient profiles.
abstract class PatientRepository {
  Stream<Patient?> watchPatientByAuthUser(String authUserId);

  Future<Patient?> getPatientById(String patientId);

  Future<Patient> createPatient(Patient patient);

  /// Updates an existing patient document; it never creates a profile.
  Future<Patient> updatePatient(Patient patient);
}
