import '../entities/test_result.dart';

abstract class TestResultRepository {
  Future<List<TestResult>> getTestResultsByPatient(String patientId);
}

