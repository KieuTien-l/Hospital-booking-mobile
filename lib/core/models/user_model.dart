import 'package:cloud_firestore/cloud_firestore.dart';

import '../entities/user_entity.dart';
import 'model_value_parser.dart';

class UserModel extends UserEntity {
  const UserModel({
    required super.id,
    required super.email,
    required super.fullName,
    required super.phone,
    required super.role,
    required super.isActive,
    this.department,
    this.accountKey,
    this.permission,
    this.status,
    this.createdAt,
    this.updatedAt,
  });

  final String? department;
  final String? accountKey;
  final String? permission;
  final String? status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory UserModel.fromJson(Map<String, dynamic> json, {String? documentId}) {
    final status = readOptionalStringForKeys(json, const [
      'TrangThai',
      'status',
    ]);
    final roleValue = readStringForKeys(json, const [
      'role',
      'Quyen',
    ]).toLowerCase();
    final role = _roleFromValue(roleValue);
    final activeFromStatus = status == null
        ? true
        : !const {
            'INACTIVE',
            'DISABLED',
            'FALSE',
            '0',
          }.contains(status.toUpperCase());

    return UserModel(
      id: documentId ?? readString(json['id']),
      email: readStringForKeys(json, const ['email', 'Email']),
      fullName: readStringForKeys(json, const ['fullName', 'HoTen']),
      phone: readStringForKeys(json, const ['phone', 'SoDienThoai']),
      role: role,
      isActive: json.containsKey('isActive')
          ? readBool(json['isActive'], fallback: true)
          : activeFromStatus,
      department: readOptionalStringForKeys(json, const ['Khoa']),
      accountKey: readOptionalStringForKeys(json, const ['MaTK']),
      permission: readOptionalStringForKeys(json, const ['Quyen']),
      status: status,
      createdAt: readDateTime(
        readFirstValue(json, const ['createdAt', 'NgayTao']),
      ),
      updatedAt: readDateTime(
        readFirstValue(json, const ['updatedAt', 'NgayCapNhat']),
      ),
    );
  }

  factory UserModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    return UserModel.fromJson(doc.data() ?? const {}, documentId: doc.id);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'fullName': fullName,
      'phone': phone,
      'role': role.name,
      'isActive': isActive,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
    };
  }

  Map<String, dynamic> toFirestoreCreate() {
    return {
      'createdAt': FieldValue.serverTimestamp(),
      'email': email,
      'fullName': fullName,
      'role': role.name,
      'isActive': isActive,
      'phone': phone,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> toMap() => toFirestoreCreate();

  static UserRole _roleFromValue(String roleValue) {
    switch (roleValue) {
      case 'doctor':
      case 'bac_si':
      case 'bác sĩ':
        return UserRole.doctor;
      case 'admin':
      case 'administrator':
      case 'quan_tri_vien':
      case 'quản trị viên':
        return UserRole.admin;
      case 'patient':
      case 'benh_nhan':
      case 'bệnh nhân':
      default:
        return UserRole.patient;
    }
  }
}
