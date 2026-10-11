import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/test_result_model.dart';

class TestResultFirebaseDatasource {
  TestResultFirebaseDatasource(this._firestore);
  final FirebaseFirestore _firestore;

  Future<List<TestResultModel>> getTestResultsByPatient(
    String patientId,
  ) async {
    final query = await _firestore
        .collection(TestResultModel.collectionName)
        .where('patientId', isEqualTo: patientId)
        .get();
    final results = query.docs
        .map((doc) => TestResultModel.fromFirestore(doc))
        .toList();
    results.sort((left, right) => right.testDate.compareTo(left.testDate));
    return results;
  }
}
