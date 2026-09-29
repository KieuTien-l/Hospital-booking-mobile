import 'package:cloud_firestore/cloud_firestore.dart';

import 'model_value_parser.dart';

class Patient {
  static const String collectionName = 'BENH_NHAN';

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

  factory Patient.fromJson(Map<String, dynamic> json, {String? documentId}) {
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

    return Patient(
      id:
          documentId ??
          readStringForKeys(json, const ['id', 'Id', 'ID', 'MaBenhNhan']),
      authUserId: readReferenceIdForKeys(json, const [
        'MaTK',
        'maTK',
        'MaNguoiDung',
        'maNguoiDung',
        'Uid',
        'uid',
        'UserId',
        'userId',
        'authUserId',
      ]),
      fullName: readStringForKeys(json, const [
        'HoTen',
        'hoTen',
        'TenBenhNhan',
        'tenBenhNhan',
        'fullName',
      ]),
      phone: readStringForKeys(json, const [
        'SoDienThoai',
        'soDienThoai',
        'phone',
        'Phone',
      ]),
      email: readStringForKeys(json, const ['Email', 'email']),
      isActive: isActive,
      dateOfBirth: readDateTime(
        readFirstValue(json, const ['NgaySinh', 'ngaySinh', 'dateOfBirth']),
      ),
      gender: readOptionalStringForKeys(json, const [
        'GioiTinh',
        'gioiTinh',
        'gender',
      ]),
      address: readOptionalStringForKeys(json, const [
        'SoNha',
        'soNha',
        'DiaChi',
        'diaChi',
        'address',
      ]),
      avatarUrl: readOptionalStringForKeys(json, const [
        'AnhDaiDien',
        'anhDaiDien',
        'HinhAnh',
        'hinhAnh',
        'avatarUrl',
      ]),
      insuranceNumber: readOptionalStringForKeys(json, const [
        'MaBHYT',
        'maBHYT',
        'insuranceNumber',
      ]),
      ethnicity: readOptionalStringForKeys(json, const ['DanToc', 'danToc']),
      occupation: readOptionalStringForKeys(json, const [
        'NgheNghiep',
        'ngheNghiep',
      ]),
      ward: readOptionalStringForKeys(json, const ['PhuongXa', 'phuongXa']),
      district: readOptionalStringForKeys(json, const [
        'QuanHuyen',
        'quanHuyen',
      ]),
      province: readOptionalStringForKeys(json, const [
        'TinhThanh',
        'tinhThanh',
      ]),
      country: readOptionalStringForKeys(json, const ['QuocGia', 'quocGia']),
      nationalId: readOptionalStringForKeys(json, const ['SoCCCD', 'soCCCD']),
      relationshipToAccountHolder: readOptionalStringForKeys(json, const [
        'QuanHeChuTaiKhoan',
        'quanHeChuTaiKhoan',
      ]),
      status: status.isEmpty ? (isActive ? 'ACTIVE' : 'INACTIVE') : status,
      createdAt: readDateTime(
        readFirstValue(json, const ['createdAt', 'CreatedAt', 'NgayTao']),
      ),
      updatedAt: readDateTime(
        readFirstValue(json, const ['updatedAt', 'UpdatedAt', 'NgayCapNhat']),
      ),
    );
  }

  factory Patient.fromMap(Map<String, dynamic> map, {String? documentId}) {
    return Patient.fromJson(map, documentId: documentId);
  }

  factory Patient.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    return Patient.fromJson(doc.data() ?? const {}, documentId: doc.id);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'authUserId': authUserId,
      'fullName': fullName,
      'phone': phone,
      'email': email,
      'isActive': isActive,
      if (dateOfBirth != null) 'dateOfBirth': dateOfBirth!.toIso8601String(),
      if (gender != null) 'gender': gender,
      if (address != null) 'address': address,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
      if (insuranceNumber != null) 'insuranceNumber': insuranceNumber,
      if (ethnicity != null) 'ethnicity': ethnicity,
      if (occupation != null) 'occupation': occupation,
      if (ward != null) 'ward': ward,
      if (district != null) 'district': district,
      if (province != null) 'province': province,
      if (country != null) 'country': country,
      if (nationalId != null) 'nationalId': nationalId,
      if (relationshipToAccountHolder != null)
        'relationshipToAccountHolder': relationshipToAccountHolder,
      'status': status,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
    };
  }

  Map<String, dynamic> toFirestore() {
    return {
      'authUserId': authUserId,
      'fullName': fullName,
      'phone': phone,
      'email': email,
      if (dateOfBirth != null) 'dateOfBirth': dateOfBirth,
      if (gender != null) 'gender': gender,
      if (address != null) 'address': address,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
      if (insuranceNumber != null) 'insuranceNumber': insuranceNumber,
      if (ethnicity != null) 'ethnicity': ethnicity,
      if (occupation != null) 'occupation': occupation,
      if (ward != null) 'ward': ward,
      if (district != null) 'district': district,
      if (province != null) 'province': province,
      if (country != null) 'country': country,
      if (nationalId != null) 'nationalId': nationalId,
      if (relationshipToAccountHolder != null)
        'relationshipToAccountHolder': relationshipToAccountHolder,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> toFirestoreCreate() {
    return {
      ...toFirestore(),
      'isActive': isActive,
      'status': status,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}

typedef PatientModel = Patient;
