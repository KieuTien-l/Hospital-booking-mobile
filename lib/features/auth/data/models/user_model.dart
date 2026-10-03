import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/user_entity.dart';
import '../../../../core/utils/model_value_parser.dart';

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
    final status = readOptionalString(json['status']);
    final roleValue = readString(json['role']).toLowerCase();
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
      email: readString(json['email']),
      fullName: readString(json['fullName']),
      phone: readString(json['phone']),
      role: role,
      isActive: json.containsKey('isActive')
          ? readBool(json['isActive'], fallback: true)
          : activeFromStatus,
      department: readOptionalString(json['department']),
      accountKey: readOptionalString(json['accountKey']),
      permission: readOptionalString(json['permission']),
      status: status,
      createdAt: readDateTime(json['createdAt']),
      updatedAt: readDateTime(json['updatedAt']),
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
        return UserRole.doctor;
      case 'admin':
      case 'administrator':
        return UserRole.admin;
      case 'patient':
      default:
        return UserRole.patient;
    }
  }
}
