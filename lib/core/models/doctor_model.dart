import 'package:cloud_firestore/cloud_firestore.dart';

import 'model_value_parser.dart';

class DoctorModel {
  const DoctorModel({
    required this.id,
    required this.userId,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.specialtyId,
    required this.yearsOfExperience,
    required this.consultationFee,
    required this.isActive,
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
  final String? specialtyName;
  final String? qualification;
  final String? biography;
  final String? avatarUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory DoctorModel.fromJson(
    Map<String, dynamic> json, {
    String? documentId,
  }) {
    String? optionalString(String key) {
      final value = readString(json[key]);
      return value.isEmpty ? null : value;
    }

    return DoctorModel(
      id: documentId ?? readString(json['id']),
      userId: readString(json['userId']),
      fullName: readString(json['fullName']),
      email: readString(json['email']),
      phone: readString(json['phone']),
      specialtyId: readString(json['specialtyId']),
      yearsOfExperience: readInt(json['yearsOfExperience']),
      consultationFee: readDouble(json['consultationFee']),
      isActive: readBool(json['isActive'], fallback: true),
      specialtyName: optionalString('specialtyName'),
      qualification: optionalString('qualification'),
      biography: optionalString('biography'),
      avatarUrl: optionalString('avatarUrl'),
      createdAt: readDateTime(json['createdAt']),
      updatedAt: readDateTime(json['updatedAt']),
    );
  }

  factory DoctorModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return DoctorModel.fromJson(doc.data() ?? const {}, documentId: doc.id);
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
      if (specialtyName != null) 'specialtyName': specialtyName,
      if (qualification != null) 'qualification': qualification,
      if (biography != null) 'biography': biography,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
    };
  }

  Map<String, dynamic> toFirestore() {
    final data = toJson()
      ..remove('id')
      ..remove('createdAt')
      ..remove('updatedAt');
    data['updatedAt'] = FieldValue.serverTimestamp();
    return data;
  }
}
