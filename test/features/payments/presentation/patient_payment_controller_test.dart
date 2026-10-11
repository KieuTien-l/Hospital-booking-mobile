import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_4/core/state/view_state.dart';
import 'package:flutter_application_4/features/payments/domain/entities/patient_payment.dart';
import 'package:flutter_application_4/features/payments/domain/repositories/patient_payment_repository.dart';
import 'package:flutter_application_4/features/payments/presentation/controllers/patient_payment_controller.dart';

class _MemoryPaymentRepository implements PatientPaymentRepository {
  _MemoryPaymentRepository(this.values);

  final List<PatientPayment> values;

  @override
  Future<List<PatientPayment>> getPaymentsByPatient(String patientId) async =>
      values.where((payment) => payment.patientId == patientId).toList();
}

void main() {
  test('loads only the selected patient payments', () async {
    final controller = PatientPaymentController(
      _MemoryPaymentRepository(const [
        PatientPayment(
          id: 'payment-1',
          patientId: 'patient-1',
          amount: 250000,
          paymentMethod: 'MOMO',
          status: 'SUCCESS',
        ),
        PatientPayment(
          id: 'payment-2',
          patientId: 'patient-2',
          amount: 180000,
          paymentMethod: 'BANK_TRANSFER',
          status: 'PENDING',
        ),
      ]),
    );

    await controller.loadPayments('patient-1');

    expect(controller.status, ViewState.success);
    expect(controller.payments.map((payment) => payment.id), ['payment-1']);
  });

  test('uses the empty state when the patient has no payments', () async {
    final controller = PatientPaymentController(_MemoryPaymentRepository(const []));

    await controller.loadPayments('patient-1');

    expect(controller.status, ViewState.empty);
    expect(controller.payments, isEmpty);
  });
}
