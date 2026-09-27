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
    this.createdAt,
    this.updatedAt,
  });

  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory UserModel.fromJson(Map<String, dynamic> json, {String? documentId}) {
    final roleValue = readString(json['role']).toLowerCase();
    final role = UserRole.values.firstWhere(
      (item) => item.name == roleValue,
      orElse: () => UserRole.patient,
    );

    return UserModel(
      id: documentId ?? readString(json['id']),
      email: readString(json['email']),
      fullName: readString(json['fullName']),
      phone: readString(json['phone']),
      role: role,
      isActive: readBool(json['isActive'], fallback: true),
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
      'email': email,
      'fullName': fullName,
      'phone': phone,
      'role': role.name,
      'isActive': isActive,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> toMap() => toFirestoreCreate();
}
