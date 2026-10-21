import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_4/features/admin/data/admin_repository.dart';
import 'package:flutter_application_4/features/admin/presentation/admin_metrics.dart';

void main() {
  test(
    'Vietnam calendar periods include both edges and exclude missing dates',
    () {
      final day = DateTime.utc(2026, 10, 21);
      expect(adminSameDay(DateTime.utc(2026, 10, 20, 17), day), isTrue);
      expect(adminSameDay(DateTime.utc(2026, 10, 21, 16, 59), day), isTrue);
      expect(adminSameDay(DateTime.utc(2026, 10, 21, 17), day), isFalse);
      expect(adminInPeriod(null, day, day), isFalse);
      expect(adminInPeriod('invalid', day, day), isFalse);
      expect(
        adminInPeriod(DateTime.utc(2026, 10, 20, 16, 59), day, day),
        isFalse,
      );
    },
  );

  test(
    'collected total uses successful payments and paidAt, never createdAt',
    () {
      final day = DateTime.utc(2026, 10, 21);
      final paymentTime = DateTime.utc(2026, 10, 21, 2);
      final records = [
        AdminRecord('paid', {
          'status': 'PAID',
          'paidAt': paymentTime,
          'amount': 150000,
        }),
        AdminRecord('success', {
          'status': 'success',
          'paidAt': paymentTime,
          'amount': '200000',
        }),
        AdminRecord('failed', {
          'status': 'FAILED',
          'paidAt': paymentTime,
          'amount': 900000,
        }),
        AdminRecord('missing', {
          'status': 'PAID',
          'createdAt': paymentTime,
          'amount': 900000,
        }),
        AdminRecord('old', {
          'status': 'PAID',
          'paidAt': DateTime.utc(2026, 10, 19),
          'amount': 900000,
        }),
        AdminRecord('negative', {
          'status': 'PAID',
          'paidAt': paymentTime,
          'amount': -5,
        }),
        AdminRecord('invalid', {
          'status': 'PAID',
          'paidAt': paymentTime,
          'amount': 'NaN',
        }),
      ];
      expect(adminCollectedTotal(records, day, day), 350000);
    },
  );
}
