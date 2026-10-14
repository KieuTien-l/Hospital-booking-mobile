import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_4/features/payments/data/models/patient_payment_model.dart';

void main() {
  test('reads canonical payment fields and tolerates a missing paid date', () {
    final payment = PatientPaymentModel.fromMap({
      'patientId': 'patient-1',
      'appointmentId': 'appointment-1',
      'amount': 250000,
      'paymentMethod': 'MOMO',
      'status': 'SUCCESS',
      'transactionCode': 'TT-0001',
      'createdAt': '2026-10-11T09:30:00.000',
    }, id: 'payment-1');

    expect(payment.id, 'payment-1');
    expect(payment.patientId, 'patient-1');
    expect(payment.appointmentId, 'appointment-1');
    expect(payment.amount, 250000);
    expect(payment.paymentMethod, 'MOMO');
    expect(payment.status, 'SUCCESS');
    expect(payment.transactionCode, 'TT-0001');
    expect(payment.paidAt, isNull);
    expect(payment.createdAt, DateTime(2026, 10, 11, 9, 30));
  });

  test('does not read legacy payment fields after migration', () {
    final payment = PatientPaymentModel.fromMap({
      'MaBN': 'patient-legacy',
      'paymentDate': '2026-10-11T09:30:00.000',
      'amount': 180000,
      'paymentMethod': 'VNPAY',
      'status': 'PENDING',
    }, id: 'payment-legacy');

    expect(payment.patientId, isEmpty);
    expect(payment.paidAt, isNull);
  });
}
