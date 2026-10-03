import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/models/doctor_model.dart';
import '../../domain/repositories/doctor_repository.dart';

/// Firestore-backed doctor repository for the BAC_SI collection.
class FirebaseDoctorRepository implements DoctorRepository {
  FirebaseDoctorRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _doctors =>
      _firestore.collection(Doctor.collectionName);

  @override
  Future<List<Doctor>> getDoctors() async {
    final snapshot = await _doctors.get();
    return snapshot.docs
        .map(Doctor.fromFirestore)
        .where((doctor) => doctor.isActive)
        .toList(growable: false);
  }

  @override
  Future<Doctor?> getDoctorById(String doctorId) async {
    final normalizedId = doctorId.trim();
    if (normalizedId.isEmpty) return null;

    final snapshot = await _doctors.doc(normalizedId).get();
    if (!snapshot.exists) return null;
    final doctor = Doctor.fromFirestore(snapshot);
    return doctor.isActive ? doctor : null;
  }

  @override
  Future<List<Doctor>> getDoctorsBySpecialty(String specialtyId) async {
    final normalizedId = specialtyId.trim();
    if (normalizedId.isEmpty) return const [];

    final snapshot = await _doctors
        .where('specialtyId', isEqualTo: normalizedId)
        .get();
    return snapshot.docs
        .map(Doctor.fromFirestore)
        .where((doctor) => doctor.isActive)
        .toList(growable: false);
  }
}
