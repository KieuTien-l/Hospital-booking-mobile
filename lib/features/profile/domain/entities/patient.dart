class Patient {
  const Patient({
    required this.id,
    required this.authUserId,
    required this.fullName,
    required this.phone,
    required this.email,
    required this.isActive,
    this.patientCode = '',
    this.ownerUserId,
    this.dateOfBirth,
    this.gender,
    this.address,
    this.avatarUrl,
    this.insuranceNumber,
    this.ethnicity,
    this.occupation,
    this.ward,
    this.district,
    this.province,
    this.country,
    this.nationalId,
    this.relationshipToAccountHolder,
    this.status = 'ACTIVE',
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String authUserId;
  final String fullName;
  final String phone;
  final String email;
  final bool isActive;

  /// Stable, printable clinical identifier. Unlike [id], this is shown on
  /// appointments, examination sheets and prescriptions.
  final String patientCode;

  /// Account that manages this profile. [authUserId] is retained for legacy
  /// data compatibility and has the same value for newly created profiles.
  final String? ownerUserId;
  final DateTime? dateOfBirth;
  final String? gender;
  final String? address;
  final String? avatarUrl;
  final String? insuranceNumber;
  final String? ethnicity;
  final String? occupation;
  final String? ward;
  final String? district;
  final String? province;
  final String? country;
  final String? nationalId;
  final String? relationshipToAccountHolder;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get uid => authUserId;
  String get ownerId =>
      ownerUserId?.trim().isNotEmpty == true ? ownerUserId!.trim() : authUserId;
  String get maTaiKhoan => authUserId;
  String get tenBenhNhan => fullName;
  String get soDienThoai => phone;
  String get trangThai => status;
}
