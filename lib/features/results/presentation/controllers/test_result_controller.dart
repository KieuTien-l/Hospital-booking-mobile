import '../../../../core/state/view_state.dart';
import '../../domain/entities/test_result.dart';
import '../../domain/repositories/test_result_repository.dart';

class TestResultController extends ViewStateController {
  TestResultController(this._repository);
  final TestResultRepository _repository;

  List<TestResult> _results = const [];
  String? _patientId;

  List<TestResult> get results => _results;
  String? get patientId => _patientId;

  Future<void> loadResults(String patientId) async {
    _patientId = patientId;
    _results = const [];
    final token = beginRequest();
    try {
      final values = await _repository.getTestResultsByPatient(patientId);
      if (!isCurrent(token)) return;
      _results = List.unmodifiable(values);
      setState(values.isEmpty ? ViewState.empty : ViewState.success);
    } catch (error) {
      if (isCurrent(token)) setState(ViewState.error, error);
    }
  }
}
