import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/health_record_model.dart';

class HealthRecordFirebaseDatasource {
  HealthRecordFirebaseDatasource(this._firestore);
  final FirebaseFirestore _firestore;

  static const String collectionName = 'HO_SO_SUC_KHOE';

  Future<List<HealthRecordModel>> getHealthRecordsByPatient(
    String patientId,
  ) async {
    final query = await _firestore
        .collection(collectionName)
        .where('patientId', isEqualTo: patientId)
        .get();
    final records = query.docs
        .map((doc) => HealthRecordModel.fromFirestore(doc))
        .toList();
    // Sort locally so reading a patient's records does not require a
    // composite Firestore index.
    records.sort((a, b) => b.recordDate.compareTo(a.recordDate));
    return List.unmodifiable(records);
  }
}
