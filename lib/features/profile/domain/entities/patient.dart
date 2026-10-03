class Patient {
  const Patient({
    required this.id,
    required this.authUserId,
    required this.fullName,
    required this.phone,
    required this.email,
    required this.isActive,
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
  String get maTaiKhoan => authUserId;
  String get tenBenhNhan => fullName;
  String get soDienThoai => phone;
  String get trangThai => status;
}
