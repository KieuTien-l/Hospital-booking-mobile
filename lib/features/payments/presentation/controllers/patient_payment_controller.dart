import '../../../../core/state/view_state.dart';
import '../../domain/entities/patient_payment.dart';
import '../../domain/repositories/patient_payment_repository.dart';

class PatientPaymentController extends ViewStateController {
  PatientPaymentController(this._repository);

  final PatientPaymentRepository _repository;
  List<PatientPayment> _payments = const [];

  List<PatientPayment> get payments => _payments;

  Future<void> loadPayments(String patientId) async {
    _payments = const [];
    final token = beginRequest();
    try {
      final values = await _repository.getPaymentsByPatient(patientId);
      if (!isCurrent(token)) return;
      _payments = List.unmodifiable(values);
      setState(values.isEmpty ? ViewState.empty : ViewState.success);
    } catch (error) {
      if (isCurrent(token)) setState(ViewState.error, error);
    }
  }
}
