import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/test_result_model.dart';

class TestResultFirebaseDatasource {
  TestResultFirebaseDatasource(this._firestore);
  final FirebaseFirestore _firestore;

  Future<List<TestResultModel>> getTestResultsByPatient(String patientId) async {
    final query = await _firestore
        .collection(TestResultModel.collectionName)
        .where('patientId', isEqualTo: patientId)
        .orderBy('testDate', descending: true)
        .get();
    return query.docs.map((doc) => TestResultModel.fromFirestore(doc)).toList();
  }
}

