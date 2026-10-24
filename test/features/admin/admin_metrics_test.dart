import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_4/features/admin/data/admin_repository.dart';
import 'package:flutter_application_4/features/admin/presentation/admin_metrics.dart';

void main() {
  test(
    'doctor reports keep different ids separate even with the same name',
    () {
      final groups = adminAppointmentsByDoctor([
        const AdminRecord('one', {
          'doctorId': 'doctor-a',
          'doctorName': 'Nguyễn An',
        }),
        const AdminRecord('two', {
          'doctorId': 'doctor-b',
          'doctorName': 'Nguyễn An',
        }),
        const AdminRecord('three', {'doctorId': 'doctor-a'}),
      ]);
      expect(groups['doctor-a']!.map((r) => r.id), ['one', 'three']);
      expect(groups['doctor-b']!.single.id, 'two');
    },
  );

  test('booking options exclude elapsed, full and mismatched slots in Vietnam time', () {
    final now = DateTime.utc(2026, 10, 26, 1); // 08:00 in Vietnam.
    final schedule = AdminRecord('schedule', {
      'workDate': DateTime.utc(2026, 10, 25, 17),
      'doctorId': 'doctor',
      'status': 'ACTIVE',
    });
    final data = <String, dynamic>{
      'workScheduleId': 'schedule',
      'doctorId': 'doctor',
      'status': 'AVAILABLE',
      'capacity': 5,
      'bookedCount': 1,
      'startTime': '08:01',
    };
    bool allowed(Map<String, dynamic> change) => adminCanBookSlot(
      AdminRecord('slot', {...data, ...change}),
      schedule,
      now: now,
    );
    expect(allowed({}), isTrue);
    for (final change in [
      {'startTime': '08:00'},
      {'startTime': '07:59'},
      {'startTime': 'bad'},
      {'bookedCount': 5},
      {'doctorId': 'other'},
      {'workScheduleId': 'other'},
      {'status': 'CANCELLED'},
    ]) {
      expect(allowed(change), isFalse, reason: '$change');
    }
  });

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
