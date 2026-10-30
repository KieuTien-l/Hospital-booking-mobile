import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/patient_model.dart';
import '../patient_profile_code.dart';
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

    // New profiles use the auth UID as their document id. Reading that exact
    // document removes the nondeterministic `limit(1)` selection that made a
    // duplicate profile capable of changing the active patient context.
    return _patients
        .doc(normalizedId)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.exists ? PatientModel.fromFirestore(snapshot) : null,
        );
  }

  /// Merges new family-profile documents (`ownerUserId`) with the canonical
  /// legacy UID document. This lets existing users migrate without losing the
  /// profile they created before family members were supported.
  Stream<List<Patient>> watchPatientsByOwner(String ownerUserId) {
    final ownerId = ownerUserId.trim();
    if (ownerId.isEmpty) return Stream.value(const []);

    late final StreamController<List<Patient>> controller;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? familySub;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? legacySub;
    var family = const <Patient>[];
    Patient? legacy;

    void emit() {
      final byId = <String, Patient>{
        for (final item in family) item.id: item,
        if (legacy != null) legacy!.id: legacy!,
      };
      final profiles = byId.values.toList()
        ..sort((left, right) {
          final leftSelf =
              left.ownerId == ownerId &&
              (left.relationshipToAccountHolder ?? '').toUpperCase() ==
                  'BẢN THÂN';
          final rightSelf =
              right.ownerId == ownerId &&
              (right.relationshipToAccountHolder ?? '').toUpperCase() ==
                  'BẢN THÂN';
          if (leftSelf != rightSelf) return leftSelf ? -1 : 1;
          return left.fullName.toLowerCase().compareTo(
            right.fullName.toLowerCase(),
          );
        });
      controller.add(List.unmodifiable(profiles));
    }

    controller = StreamController<List<Patient>>(
      onListen: () {
        familySub = _patients
            .where('ownerUserId', isEqualTo: ownerId)
            .snapshots()
            .listen((snapshot) {
              family = snapshot.docs.map(PatientModel.fromFirestore).toList();
              emit();
            }, onError: controller.addError);
        legacySub = _patients.doc(ownerId).snapshots().listen((snapshot) {
          legacy = snapshot.exists
              ? PatientModel.fromFirestore(snapshot)
              : null;
          emit();
        }, onError: controller.addError);
      },
      onCancel: () async {
        await familySub?.cancel();
        await legacySub?.cancel();
      },
    );
    return controller.stream;
  }

  Future<Patient?> getPatientById(String patientId) async {
    final normalizedId = patientId.trim();
    if (normalizedId.isEmpty) return null;

    final snapshot = await _patients.doc(normalizedId).get();
    return snapshot.exists ? PatientModel.fromFirestore(snapshot) : null;
  }

  Future<Patient> createPatient(Patient patient) async {
    _validateAuthUserId(patient);
    // A profile belongs to an account but has an independent auto-id so one
    // account can safely manage itself, parents and dependants.
    for (var attempt = 0; attempt < 8; attempt++) {
      final document = _patients.doc();
      final code = patient.patientCode.trim().isEmpty
          ? PatientProfileCode.generate()
          : patient.patientCode.trim();
      final codeDocument = _firestore.collection('MA_HO_SO').doc(code);
      final savedPatient = _withId(patient, document.id, code);
      try {
        final saved = await _firestore.runTransaction((transaction) async {
          if ((await transaction.get(codeDocument)).exists) {
            throw const _PatientCodeCollision();
          }
          transaction.set(document, savedPatient.toFirestoreCreate());
          transaction.set(codeDocument, {
            'patientId': document.id,
            'ownerUserId': savedPatient.ownerId,
            'createdAt': FieldValue.serverTimestamp(),
          });
          return savedPatient;
        });
        return saved;
      } on _PatientCodeCollision {
        if (patient.patientCode.trim().isNotEmpty) rethrow;
      }
    }
    throw const BookingException(
      'Không thể tạo mã hồ sơ duy nhất. Vui lòng thử lại.',
    );
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
    final existingSnapshot = await document.get();
    if (!existingSnapshot.exists) {
      throw const BookingException('The patient profile does not exist.');
    }

    final existing = PatientModel.fromFirestore(existingSnapshot);
    if (existing.ownerId != patient.ownerId) {
      throw const BookingException('Bạn không có quyền cập nhật hồ sơ này.');
    }

    // update() changes only fields supplied by Patient.toFirestore(), so
    // existing fields that are not editable by this flow are preserved.
    final saved = _withId(
      patient,
      patientId,
      patient.patientCode.trim().isEmpty
          ? existing.patientCode
          : patient.patientCode,
    );
    await document.update(saved.toFirestore());
    return saved;
  }

  void _validateAuthUserId(Patient patient) {
    if (patient.authUserId.trim().isEmpty) {
      throw const BookingException(
        'A Firebase user id is required for a patient profile.',
      );
    }
  }

  PatientModel _withId(Patient patient, String id, String patientCode) {
    return PatientModel(
      id: id,
      authUserId: patient.authUserId.trim(),
      fullName: patient.fullName.trim(),
      phone: patient.phone.trim(),
      email: patient.email.trim(),
      isActive: patient.isActive,
      patientCode: patientCode,
      ownerUserId: patient.ownerId,
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

class _PatientCodeCollision implements Exception {
  const _PatientCodeCollision();
}
