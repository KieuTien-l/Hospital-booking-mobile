import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/patient_model.dart';
import '../../../appointments/domain/exceptions/booking_exception.dart';

/// Firestore-backed patient profile repository for BENH_NHAN.
class PatientFirebaseDatasource {
  PatientFirebaseDatasource({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _patients =>
      _firestore.collection(PatientModel.collectionName);

  Stream<Patient?> watchPatientByAuthUser(String authUserId) {
    final normalizedId = authUserId.trim();
    if (normalizedId.isEmpty) return Stream.value(null);

    return _patients
        .where('authUserId', isEqualTo: normalizedId)
        .limit(1)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.isEmpty
              ? null
              : PatientModel.fromFirestore(snapshot.docs.first),
        );
  }

  Future<Patient?> getPatientById(String patientId) async {
    final normalizedId = patientId.trim();
    if (normalizedId.isEmpty) return null;

    final snapshot = await _patients.doc(normalizedId).get();
    return snapshot.exists ? PatientModel.fromFirestore(snapshot) : null;
  }

  Future<Patient> createPatient(Patient patient) async {
    _validateAuthUserId(patient);
    final document = patient.id.trim().isEmpty
        ? _patients.doc()
        : _patients.doc(patient.id.trim());
    if ((await document.get()).exists) {
      throw const BookingException('A patient profile already exists.');
    }

    final savedPatient = _withId(patient, document.id);
    await document.set(savedPatient.toFirestoreCreate());
    return savedPatient;
  }

  Future<Patient> updatePatient(Patient patient) async {
    _validateAuthUserId(patient);
    final patientId = patient.id.trim();
    if (patientId.isEmpty) {
      throw const BookingException(
        'A patient id is required to update a patient profile.',
      );
    }

    final document = _patients.doc(patientId);
    if (!(await document.get()).exists) {
      throw const BookingException('The patient profile does not exist.');
    }

    // update() changes only fields supplied by Patient.toFirestore(), so
    // existing fields that are not editable by this flow are preserved.
    await document.update(PatientModel.fromEntity(patient).toFirestore());
    return patient;
  }

  void _validateAuthUserId(Patient patient) {
    if (patient.authUserId.trim().isEmpty) {
      throw const BookingException(
        'A Firebase user id is required for a patient profile.',
      );
    }
  }

  PatientModel _withId(Patient patient, String id) {
    return PatientModel(
      id: id,
      authUserId: patient.authUserId.trim(),
      fullName: patient.fullName.trim(),
      phone: patient.phone.trim(),
      email: patient.email.trim(),
      isActive: patient.isActive,
      dateOfBirth: patient.dateOfBirth,
      gender: patient.gender,
      address: patient.address,
      avatarUrl: patient.avatarUrl,
      insuranceNumber: patient.insuranceNumber,
      ethnicity: patient.ethnicity,
      occupation: patient.occupation,
      ward: patient.ward,
      district: patient.district,
      province: patient.province,
      country: patient.country,
      nationalId: patient.nationalId,
      relationshipToAccountHolder: patient.relationshipToAccountHolder,
      status: patient.status,
      createdAt: patient.createdAt,
      updatedAt: patient.updatedAt,
    );
  }
}
