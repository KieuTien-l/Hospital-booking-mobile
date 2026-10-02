import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/models/specialty_model.dart';
import '../../domain/repositories/specialty_repository.dart';

/// Firestore-backed specialty repository for the CHUYEN_KHOA collection.
class FirebaseSpecialtyRepository implements SpecialtyRepository {
  FirebaseSpecialtyRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _specialties =>
      _firestore.collection(Specialty.collectionName);

  @override
  Stream<List<Specialty>> watchSpecialties() {
    return _specialties.snapshots().map(
      (snapshot) => snapshot.docs
          .map(Specialty.fromFirestore)
          .where((specialty) => specialty.isActive)
          .toList(growable: false),
    );
  }
}
