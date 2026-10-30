import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_4/features/profile/data/patient_profile_code.dart';

void main() {
  test('creates a printable fixed-format patient profile code', () {
    final code = PatientProfileCode.generate(Random(7));

    expect(code, matches(RegExp(r'^HS-[A-Z0-9]{4}-[A-Z0-9]{4}$')));
    expect(code, isNot(contains('0')));
    expect(code, isNot(contains('1')));
  });
}
