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
    final status = readStringForKeys(json, const ['status']);
    final isActive = status.isNotEmpty
        ? !const {
            'INACTIVE',
            'DISABLED',
            'FALSE',
            '0',
          }.contains(status.toUpperCase())
        : readBool(json['isActive'], fallback: true);

    return Doctor(
      id: documentId ?? readString(json['id']),
      userId: readReferenceId(json['userId']),
      fullName: readString(json['fullName']),
      email: readString(json['email']),
      phone: readString(json['phone']),
      specialtyId: readReferenceId(json['specialtyId']),
      yearsOfExperience: readInt(json['yearsOfExperience']),
      consultationFee: readDouble(json['consultationFee']),
      isActive: isActive,
      status: status.isEmpty ? (isActive ? 'ACTIVE' : 'INACTIVE') : status,
      specialtyName: readOptionalString(json['specialtyName']),
      qualification: readOptionalString(json['qualification']),
      biography: readOptionalString(json['biography']),
      avatarUrl: readOptionalString(json['avatarUrl']),
      createdAt: readDateTime(json['createdAt']),
      updatedAt: readDateTime(json['updatedAt']),
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
