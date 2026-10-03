import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/specialty_model.dart';

/// Firestore-backed specialty repository for the CHUYEN_KHOA collection.
class SpecialtyFirebaseDatasource {
  SpecialtyFirebaseDatasource({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _specialties =>
      _firestore.collection(SpecialtyModel.collectionName);

  Stream<List<Specialty>> watchSpecialties() {
    return _specialties.snapshots().map(
      (snapshot) => snapshot.docs
          .map(SpecialtyModel.fromFirestore)
          .where((specialty) => specialty.isActive)
          .toList(growable: false),
    );
  }
}
