class Doctor {
  const Doctor({
    required this.id,
    required this.userId,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.specialtyId,
    required this.yearsOfExperience,
    required this.consultationFee,
    required this.isActive,
    this.status = 'ACTIVE',
    this.specialtyName,
    this.qualification,
    this.biography,
    this.avatarUrl,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String userId;
  final String fullName;
  final String email;
  final String phone;
  final String specialtyId;
  final int yearsOfExperience;
  final double consultationFee;
  final bool isActive;
  final String status;
  final String? specialtyName;
  final String? qualification;
  final String? biography;
  final String? avatarUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get maChuyenKhoa => specialtyId;
  String get tenBacSi => fullName;
  String get trangThai => status;
}
