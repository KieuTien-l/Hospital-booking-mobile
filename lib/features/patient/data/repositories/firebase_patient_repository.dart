import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/models/patient_model.dart';
import '../../domain/exceptions/booking_exception.dart';
import '../../domain/repositories/patient_repository.dart';

/// Firestore-backed patient profile repository for BENH_NHAN.
class FirebasePatientRepository implements PatientRepository {
  FirebasePatientRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _patients =>
      _firestore.collection(Patient.collectionName);

  @override
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
              : Patient.fromFirestore(snapshot.docs.first),
        );
  }

  @override
  Future<Patient?> getPatientById(String patientId) async {
    final normalizedId = patientId.trim();
    if (normalizedId.isEmpty) return null;

    final snapshot = await _patients.doc(normalizedId).get();
    return snapshot.exists ? Patient.fromFirestore(snapshot) : null;
  }

  @override
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

  @override
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
    await document.update(patient.toFirestore());
    return patient;
  }

  void _validateAuthUserId(Patient patient) {
    if (patient.authUserId.trim().isEmpty) {
      throw const BookingException(
        'A Firebase user id is required for a patient profile.',
      );
    }
  }

  Patient _withId(Patient patient, String id) {
    return Patient(
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
