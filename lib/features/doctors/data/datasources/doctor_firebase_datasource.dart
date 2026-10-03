import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/doctor_model.dart';

/// Firestore-backed doctor repository for the BAC_SI collection.
class DoctorFirebaseDatasource {
  DoctorFirebaseDatasource({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _doctors =>
      _firestore.collection(DoctorModel.collectionName);

  Future<List<Doctor>> getDoctors() async {
    final snapshot = await _doctors.get();
    return snapshot.docs
        .map(DoctorModel.fromFirestore)
        .where((doctor) => doctor.isActive)
        .toList(growable: false);
  }

  Future<Doctor?> getDoctorById(String doctorId) async {
    final normalizedId = doctorId.trim();
    if (normalizedId.isEmpty) return null;

    final snapshot = await _doctors.doc(normalizedId).get();
    if (!snapshot.exists) return null;
    final doctor = DoctorModel.fromFirestore(snapshot);
    return doctor.isActive ? doctor : null;
  }

  Future<List<Doctor>> getDoctorsBySpecialty(String specialtyId) async {
    final normalizedId = specialtyId.trim();
    if (normalizedId.isEmpty) return const [];

    final snapshot = await _doctors
        .where('specialtyId', isEqualTo: normalizedId)
        .get();
    return snapshot.docs
        .map(DoctorModel.fromFirestore)
        .where((doctor) => doctor.isActive)
        .toList(growable: false);
  }
}
