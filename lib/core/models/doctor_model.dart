import 'package:cloud_firestore/cloud_firestore.dart';

import 'model_value_parser.dart';

class Doctor {
  static const String collectionName = 'BAC_SI';

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

  factory Doctor.fromJson(Map<String, dynamic> json, {String? documentId}) {
    final status = readStringForKeys(json, const [
      'TrangThai',
      'trangThai',
      'status',
    ]);
    final isActive = status.isNotEmpty
        ? !const {
            'INACTIVE',
            'DISABLED',
            'FALSE',
            '0',
          }.contains(status.toUpperCase())
        : readBool(
            readFirstValue(json, const ['isActive', 'active']),
            fallback: true,
          );

    return Doctor(
      id: documentId ?? readStringForKeys(json, const ['id', 'Id', 'ID']),
      userId: readReferenceIdForKeys(json, const [
        'MaTK',
        'maTK',
        'MaNguoiDung',
        'maNguoiDung',
        'userId',
        'UserId',
      ]),
      fullName: readStringForKeys(json, const [
        'HoTen',
        'hoTen',
        'TenBacSi',
        'tenBacSi',
        'fullName',
        'name',
        'Name',
      ]),
      email: readStringForKeys(json, const ['Email', 'email']),
      phone: readStringForKeys(json, const [
        'SoDienThoai',
        'soDienThoai',
        'phone',
        'Phone',
      ]),
      specialtyId: readReferenceIdForKeys(json, const [
        'MaCK',
        'maCK',
        'MaChuyenKhoa',
        'maChuyenKhoa',
        'ChuyenKhoaId',
        'chuyenKhoaId',
        'specialtyId',
      ]),
      yearsOfExperience: readInt(
        readFirstValue(json, const [
          'KinhNghiem',
          'kinhNghiem',
          'SoNamKinhNghiem',
          'yearsOfExperience',
        ]),
      ),
      consultationFee: readDouble(
        readFirstValue(json, const [
          'GiaKham',
          'giaKham',
          'PhiKham',
          'consultationFee',
        ]),
      ),
      isActive: isActive,
      status: status.isEmpty ? (isActive ? 'ACTIVE' : 'INACTIVE') : status,
      specialtyName: readOptionalStringForKeys(json, const [
        'TenChuyenKhoa',
        'specialtyName',
      ]),
      qualification: readOptionalStringForKeys(json, const [
        'HocHamHocVi',
        'hocHamHocVi',
        'BangCap',
        'qualification',
      ]),
      biography: readOptionalStringForKeys(json, const [
        'MoTaChiTiet',
        'moTaChiTiet',
        'MoTa',
        'biography',
      ]),
      avatarUrl: readOptionalStringForKeys(json, const [
        'AnhDaiDien',
        'anhDaiDien',
        'HinhAnh',
        'hinhAnh',
        'avatarUrl',
      ]),
      createdAt: readDateTime(
        readFirstValue(json, const ['createdAt', 'CreatedAt', 'NgayTao']),
      ),
      updatedAt: readDateTime(
        readFirstValue(json, const ['updatedAt', 'UpdatedAt', 'NgayCapNhat']),
      ),
    );
  }

  factory Doctor.fromMap(Map<String, dynamic> map, {String? documentId}) {
    return Doctor.fromJson(map, documentId: documentId);
  }

  factory Doctor.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    return Doctor.fromJson(doc.data() ?? const {}, documentId: doc.id);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'fullName': fullName,
      'email': email,
      'phone': phone,
      'specialtyId': specialtyId,
      'yearsOfExperience': yearsOfExperience,
      'consultationFee': consultationFee,
      'isActive': isActive,
      'status': status,
      if (specialtyName != null) 'specialtyName': specialtyName,
      if (qualification != null) 'qualification': qualification,
      if (biography != null) 'biography': biography,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
    };
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'fullName': fullName,
      'email': email,
      'phone': phone,
      'specialtyId': specialtyId,
      'yearsOfExperience': yearsOfExperience,
      'consultationFee': consultationFee,
      'isActive': isActive,
      'status': status,
      if (specialtyName != null) 'specialtyName': specialtyName,
      if (qualification != null) 'qualification': qualification,
      if (biography != null) 'biography': biography,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

typedef DoctorModel = Doctor;
