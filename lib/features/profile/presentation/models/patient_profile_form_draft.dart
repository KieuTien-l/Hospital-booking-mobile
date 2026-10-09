/// Values collected by [PatientProfileForm] before the profile is persisted.
class PatientProfileFormDraft {
  String familyName = '';
  String givenName = '';
  DateTime? dateOfBirth;
  String? ethnicity;
  String? gender;
  String? occupation;
  String? relationshipToAccountHolder;
  String phone = '';
  String email = '';
  String nationalId = '';
  String personalId = '';
  String passport = '';
  String country = 'Việt Nam';
  String province = '';
  String ward = '';
  String streetAddress = '';

  String get fullName => '$familyName $givenName'.trim();

  /// The current patient schema has one identity field; retain the first
  /// document supplied by the form in the order shown to the patient.
  String get identityDocument {
    for (final value in [nationalId, personalId, passport]) {
      final normalized = value.trim();
      if (normalized.isNotEmpty) return normalized;
    }
    return '';
  }

  String get address => [
    streetAddress,
    ward,
    province,
    country,
  ].map((value) => value.trim()).where((value) => value.isNotEmpty).join(', ');
}
