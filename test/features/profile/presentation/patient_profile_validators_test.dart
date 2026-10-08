import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_4/features/profile/presentation/validators/patient_profile_validators.dart';

void main() {
  test(
    'Names support Vietnamese and reject empty, numeric and oversized input',
    () {
      for (final value in [
        'Nguyễn Minh',
        'Đặng',
        'Nguye\u0302\u0303n',
        "O'Connor",
        'Anne-Marie',
      ]) {
        expect(PatientProfileValidators.name(value, 'Tên'), isNull);
      }
      for (final value in [null, '  ', 'An123', '<An>', 'a' * 101]) {
        expect(PatientProfileValidators.name(value, 'Tên'), isNotNull);
      }
    },
  );

  test('Phone validates digit count and separators', () {
    for (final value in [
      '',
      '0901234567',
      '090 123 4567',
      '+84901234567',
      '+1-202-555-0123',
    ]) {
      expect(PatientProfileValidators.phone(value), isNull);
    }
    for (final value in [
      '-------',
      '0901234',
      '090123456789',
      'abcdefghi',
      '+000000000',
      '+1234567890123456',
      '090..1234567',
    ]) {
      expect(PatientProfileValidators.phone(value), isNotNull);
    }
  });

  test('Email validates local part and domain labels', () {
    for (final value in ['', 'an@example.com', 'an+booking@hospital.com.vn']) {
      expect(PatientProfileValidators.email(value), isNull);
    }
    for (final value in [
      'invalid',
      '.an@example.com',
      'an..nguyen@example.com',
      'an@-example.com',
      'an@example..com',
      'an@exam_ple.com',
      'an@com',
      'an @example.com',
    ]) {
      expect(PatientProfileValidators.email(value), isNotNull);
    }
  });

  test(
    'Documents preserve leading zeros and reject malformed entered values',
    () {
      for (final key in ['nationalId', 'personalId']) {
        expect(PatientProfileValidators.document('000000000001', key), isNull);
        expect(PatientProfileValidators.document('', key), isNull);
        for (final value in [
          '123',
          '1234567890123',
          '12345678901a',
          '123 456789012',
        ]) {
          expect(PatientProfileValidators.document(value, key), isNotNull);
        }
      }
      expect(
        PatientProfileValidators.document('DEMO12345', 'passport'),
        isNull,
      );
      for (final value in ['123', 'A 123456', 'A!123456', 'A' * 21]) {
        expect(PatientProfileValidators.document(value, 'passport'), isNotNull);
      }
    },
  );

  test('Optional addresses reject whitespace, control characters and excess length', () {
    expect(PatientProfileValidators.address('', 'Địa chỉ'), isNull);
    expect(
      PatientProfileValidators.address('12/3 Nguyễn Huệ', 'Địa chỉ'),
      isNull,
    );
    for (final value in ['   ', '!!!', 'a\naddress', 'a' * 101]) {
      expect(PatientProfileValidators.address(value, 'Địa chỉ'), isNotNull);
    }
    expect(
      PatientProfileValidators.selection('invalid', 'Dân tộc', ['Kinh']),
      isNotNull,
    );
    expect(
      PatientProfileValidators.selection('Kinh', 'Dân tộc', ['Kinh']),
      isNull,
    );
  });
}
