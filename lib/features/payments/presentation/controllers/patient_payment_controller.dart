import '../../../../core/state/view_state.dart';
import '../../domain/entities/patient_payment.dart';
import '../../domain/repositories/patient_payment_repository.dart';

class PatientPaymentController extends ViewStateController {
  PatientPaymentController(this._repository);

  final PatientPaymentRepository _repository;
  List<PatientPayment> _payments = const [];

  List<PatientPayment> get payments => _payments;

  Future<void> loadPayments(String patientId) async {
    await loadPaymentsForPatients([patientId]);
  }

  Future<void> loadPaymentsForPatients(Iterable<String> patientIds) async {
    _payments = const [];
    final token = beginRequest();
    try {
      final ids = patientIds
          .map((id) => id.trim())
          .where((id) => id.isNotEmpty)
          .toSet();
      final groups = await Future.wait(
        ids.map(_repository.getPaymentsByPatient),
      );
      final values = groups.expand((items) => items).toList()
        ..sort((left, right) {
          final leftDate = left.paidAt ?? left.createdAt;
          final rightDate = right.paidAt ?? right.createdAt;
          return (rightDate ?? DateTime(0)).compareTo(leftDate ?? DateTime(0));
        });
      if (!isCurrent(token)) return;
      _payments = List.unmodifiable(values);
      setState(values.isEmpty ? ViewState.empty : ViewState.success);
    } catch (error) {
      if (isCurrent(token)) setState(ViewState.error, error);
    }
  }
}
