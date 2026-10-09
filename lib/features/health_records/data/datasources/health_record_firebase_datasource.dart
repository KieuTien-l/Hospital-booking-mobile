import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/health_record_model.dart';

class HealthRecordFirebaseDatasource {
  HealthRecordFirebaseDatasource(this._firestore);
  final FirebaseFirestore _firestore;

  static const String collectionName = 'HO_SO_SUC_KHOE';

  Future<List<HealthRecordModel>> getHealthRecordsByPatient(String patientId) async {
    final query = await _firestore
        .collection(collectionName)
        .where('patientId', isEqualTo: patientId)
        .orderBy('recordDate', descending: true)
        .get();
    return query.docs.map((doc) => HealthRecordModel.fromFirestore(doc)).toList();
  }
}

