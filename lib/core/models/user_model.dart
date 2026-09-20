import 'package:cloud_firestore/cloud_firestore.dart';
import '../entities/user_entity.dart';

class UserModel extends UserEntity {
  const UserModel({
    required super.id,
    required super.email,
    required super.fullName,
    required super.phone,
    required super.role,
    required super.isActive,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) {
      throw Exception("Document data is null");
    }

    UserRole parsedRole = UserRole.patient;
    if (data['role'] == 'doctor') {
      parsedRole = UserRole.doctor;
    } else if (data['role'] == 'admin') {
      parsedRole = UserRole.admin;
    }

    return UserModel(
      id: doc.id,
      email: data['email'] ?? '',
      fullName: data['fullName'] ?? '',
      phone: data['phone'] ?? '',
      role: parsedRole,
      isActive: data['isActive'] ?? true, // Mặc định true nếu chưa set
    );
  }

  Map<String, dynamic> toMap() {
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
}
