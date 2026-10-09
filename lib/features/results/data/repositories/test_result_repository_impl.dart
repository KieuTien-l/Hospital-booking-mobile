import '../../domain/entities/test_result.dart';
import '../../domain/repositories/test_result_repository.dart';
import '../datasources/test_result_firebase_datasource.dart';

class TestResultRepositoryImpl implements TestResultRepository {
  TestResultRepositoryImpl(this._datasource);
  final TestResultFirebaseDatasource _datasource;

  @override
  Future<List<TestResult>> getTestResultsByPatient(String patientId) =>
      _datasource.getTestResultsByPatient(patientId);
}

