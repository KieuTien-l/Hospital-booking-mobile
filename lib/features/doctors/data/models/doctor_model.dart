import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/utils/model_value_parser.dart';
import '../../domain/entities/doctor.dart';
export '../../domain/entities/doctor.dart';

class DoctorModel extends Doctor {
  static const String collectionName = 'BAC_SI';

  const DoctorModel({
    required super.id,
    required super.userId,
    required super.fullName,
    required super.email,
    required super.phone,
    required super.specialtyId,
    required super.yearsOfExperience,
    required super.consultationFee,
    required super.isActive,
    super.status = 'ACTIVE',
    super.specialtyName,
    super.qualification,
    super.biography,
    super.avatarUrl,
    super.dateOfBirth,
    super.gender,
    super.address,
    super.acceptingBookings = true,
    super.createdAt,
    super.updatedAt,
  });

  factory DoctorModel.fromEntity(Doctor value) => DoctorModel(
    id: value.id,
    userId: value.userId,
    fullName: value.fullName,
    email: value.email,
    phone: value.phone,
    specialtyId: value.specialtyId,
    yearsOfExperience: value.yearsOfExperience,
    consultationFee: value.consultationFee,
    isActive: value.isActive,
    status: value.status,
    specialtyName: value.specialtyName,
    qualification: value.qualification,
    biography: value.biography,
    avatarUrl: value.avatarUrl,
    dateOfBirth: value.dateOfBirth,
    gender: value.gender,
    address: value.address,
    acceptingBookings: value.acceptingBookings,
    createdAt: value.createdAt,
    updatedAt: value.updatedAt,
  );

  factory DoctorModel.fromJson(
    Map<String, dynamic> json, {
    String? documentId,
  }) {
    final status = readStringForKeys(json, const ['status']);
    final isActive = status.isNotEmpty
        ? !const {
            'INACTIVE',
            'DISABLED',
            'FALSE',
            '0',
          }.contains(status.toUpperCase())
        : readBool(json['isActive'], fallback: true);

    return DoctorModel(
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
      dateOfBirth: readDateTime(json['dateOfBirth']),
      gender: readOptionalString(json['gender']),
      address: readOptionalString(json['address']),
      acceptingBookings: readBool(json['acceptingBookings'], fallback: true),
      createdAt: readDateTime(json['createdAt']),
      updatedAt: readDateTime(json['updatedAt']),
    );
  }

  factory DoctorModel.fromMap(Map<String, dynamic> map, {String? documentId}) {
    return DoctorModel.fromJson(map, documentId: documentId);
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
      'status': status,
      if (specialtyName != null) 'specialtyName': specialtyName,
      if (qualification != null) 'qualification': qualification,
      if (biography != null) 'biography': biography,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
      if (dateOfBirth != null) 'dateOfBirth': dateOfBirth!.toIso8601String(),
      if (gender != null) 'gender': gender,
      if (address != null) 'address': address,
      'acceptingBookings': acceptingBookings,
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
      if (dateOfBirth != null) 'dateOfBirth': dateOfBirth,
      if (gender != null) 'gender': gender,
      if (address != null) 'address': address,
      'acceptingBookings': acceptingBookings,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
