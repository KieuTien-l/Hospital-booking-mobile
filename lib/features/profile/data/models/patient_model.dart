import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/utils/model_value_parser.dart';
import '../../domain/entities/patient.dart';
export '../../domain/entities/patient.dart';

class PatientModel extends Patient {
  static const String collectionName = 'BENH_NHAN';

  const PatientModel({
    required super.id,
    required super.authUserId,
    required super.fullName,
    required super.phone,
    required super.email,
    required super.isActive,
    super.dateOfBirth,
    super.gender,
    super.address,
    super.avatarUrl,
    super.insuranceNumber,
    super.ethnicity,
    super.occupation,
    super.ward,
    super.district,
    super.province,
    super.country,
    super.nationalId,
    super.relationshipToAccountHolder,
    super.status = 'ACTIVE',
    super.createdAt,
    super.updatedAt,
  });

  factory PatientModel.fromEntity(Patient value) => PatientModel(
    id: value.id,
    authUserId: value.authUserId,
    fullName: value.fullName,
    phone: value.phone,
    email: value.email,
    isActive: value.isActive,
    dateOfBirth: value.dateOfBirth,
    gender: value.gender,
    address: value.address,
    avatarUrl: value.avatarUrl,
    insuranceNumber: value.insuranceNumber,
    ethnicity: value.ethnicity,
    occupation: value.occupation,
    ward: value.ward,
    district: value.district,
    province: value.province,
    country: value.country,
    nationalId: value.nationalId,
    relationshipToAccountHolder: value.relationshipToAccountHolder,
    status: value.status,
    createdAt: value.createdAt,
    updatedAt: value.updatedAt,
  );

  factory PatientModel.fromJson(
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

    return PatientModel(
      id: documentId ?? readString(json['id']),
      authUserId: readReferenceId(json['authUserId']),
      fullName: readString(json['fullName']),
      phone: readString(json['phone']),
      email: readString(json['email']),
      isActive: isActive,
      dateOfBirth: readDateTime(json['dateOfBirth']),
      gender: readOptionalString(json['gender']),
      address: readOptionalString(json['address']),
      avatarUrl: readOptionalString(json['avatarUrl']),
      insuranceNumber: readOptionalString(json['insuranceNumber']),
      ethnicity: readOptionalString(json['ethnicity']),
      occupation: readOptionalString(json['occupation']),
      ward: readOptionalString(json['ward']),
      district: readOptionalString(json['district']),
      province: readOptionalString(json['province']),
      country: readOptionalString(json['country']),
      nationalId: readOptionalString(json['nationalId']),
      relationshipToAccountHolder: readOptionalString(
        json['relationshipToAccountHolder'],
      ),
      status: status.isEmpty ? (isActive ? 'ACTIVE' : 'INACTIVE') : status,
      createdAt: readDateTime(json['createdAt']),
      updatedAt: readDateTime(json['updatedAt']),
    );
  }

  factory PatientModel.fromMap(Map<String, dynamic> map, {String? documentId}) {
    return PatientModel.fromJson(map, documentId: documentId);
  }

  factory PatientModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return PatientModel.fromJson(doc.data() ?? const {}, documentId: doc.id);
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
