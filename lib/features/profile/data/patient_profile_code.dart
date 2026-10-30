import 'dart:math';

/// Human-readable identifier printed on clinical documents. It deliberately
/// contains no personal data and is separate from Firestore document ids.
abstract final class PatientProfileCode {
  static const _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  static String generate([Random? random]) {
    final source = random ?? Random.secure();
    String segment(int length) => List.generate(
      length,
      (_) => _alphabet[source.nextInt(_alphabet.length)],
    ).join();
    return 'HS-${segment(4)}-${segment(4)}';
  }
}
