import '../entities/health_record.dart';

abstract class HealthRecordRepository {
  Future<List<HealthRecord>> getHealthRecordsByPatient(String patientId);
}

