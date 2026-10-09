import '../../domain/entities/health_record.dart';
import '../../domain/repositories/health_record_repository.dart';
import '../datasources/health_record_firebase_datasource.dart';

class HealthRecordRepositoryImpl implements HealthRecordRepository {
  HealthRecordRepositoryImpl(this._datasource);
  final HealthRecordFirebaseDatasource _datasource;

  @override
  Future<List<HealthRecord>> getHealthRecordsByPatient(String patientId) =>
      _datasource.getHealthRecordsByPatient(patientId);
}

