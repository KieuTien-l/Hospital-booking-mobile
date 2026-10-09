import '../../../../core/state/view_state.dart';
import '../../domain/entities/health_record.dart';
import '../../domain/repositories/health_record_repository.dart';

class HealthRecordController extends ViewStateController {
  HealthRecordController(this._repository);
  final HealthRecordRepository _repository;
  
  List<HealthRecord> _records = const [];
  List<HealthRecord> get records => _records;

  Future<void> loadRecords(String patientId) async {
    _records = const [];
    final token = beginRequest();
    try {
      final values = await _repository.getHealthRecordsByPatient(patientId);
      if (!isCurrent(token)) return;
      _records = List.unmodifiable(values);
      setState(values.isEmpty ? ViewState.empty : ViewState.success);
    } catch (error) {
      if (isCurrent(token)) setState(ViewState.error, error);
    }
  }
}

