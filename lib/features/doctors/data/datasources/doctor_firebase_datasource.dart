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
    return (await getAllDoctors())
        .where((doctor) => doctor.isActive)
        .toList(growable: false);
  }

  /// Includes inactive profiles so administrators can detect an invalid
  /// specialty assignment instead of silently excluding it from the report.
  Future<List<Doctor>> getAllDoctors() async {
    final snapshot = await _doctors.get();
    return snapshot.docs.map(DoctorModel.fromFirestore).toList(growable: false);
  }

  Future<Doctor?> getDoctorById(String doctorId) async {
    final normalizedId = doctorId.trim();
    if (normalizedId.isEmpty) return null;

    final snapshot = await _doctors.doc(normalizedId).get();
    if (!snapshot.exists) return null;
    return DoctorModel.fromFirestore(snapshot);
  }

  /// Resolves the doctor profile that belongs to the signed-in Firebase user.
  ///
  /// Newer doctor profiles store the Firebase Auth UID in `BAC_SI.userId`.
  /// Existing production profiles instead store `TAI_KHOAN.accountKey`; retain
  /// that lookup as a read-only compatibility path while data is migrated.
  Future<Doctor?> getDoctorByUserId(String userId) async {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) return null;

    final doctor = await _findActiveDoctorByUserKey(normalizedUserId);
    if (doctor != null) return doctor;

    final account = await _firestore
        .collection('TAI_KHOAN')
        .doc(normalizedUserId)
        .get();
    final accountKey = account.data()?['accountKey'];
    final legacyUserId = accountKey is String
        ? accountKey.trim()
        : accountKey?.toString().trim() ?? '';
    if (legacyUserId.isEmpty || legacyUserId == normalizedUserId) return null;

    return _findActiveDoctorByUserKey(legacyUserId);
  }

  Future<Doctor?> _findActiveDoctorByUserKey(String userKey) async {
    final snapshot = await _doctors.where('userId', isEqualTo: userKey).get();
    final doctors = snapshot.docs
        .map(DoctorModel.fromFirestore)
        .where((doctor) => doctor.isActive)
        .toList();
    if (doctors.length > 1) {
      throw StateError('Tài khoản đang liên kết với nhiều hồ sơ bác sĩ.');
    }
    return doctors.firstOrNull;
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
