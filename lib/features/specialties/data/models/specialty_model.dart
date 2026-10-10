import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/utils/model_value_parser.dart';
import '../../domain/entities/specialty.dart';
export '../../domain/entities/specialty.dart';

class SpecialtyModel extends Specialty {
  static const String collectionName = 'CHUYEN_KHOA';

  const SpecialtyModel({
    required super.id,
    required super.name,
    required super.description,
    required super.isActive,
    super.status = 'ACTIVE',
    super.imageUrl,
    super.createdAt,
    super.updatedAt,
  });

  factory SpecialtyModel.fromEntity(Specialty value) => SpecialtyModel(
    id: value.id,
    name: value.name,
    description: value.description,
    isActive: value.isActive,
    status: value.status,
    imageUrl: value.imageUrl,
    createdAt: value.createdAt,
    updatedAt: value.updatedAt,
  );

  factory SpecialtyModel.fromJson(
    Map<String, dynamic> json, {
    String? documentId,
  }) {
    final status = readStringForKeys(json, const ['status', 'TrangThai']);
    final isActive = status.isNotEmpty
        ? !const {
            'INACTIVE',
            'DISABLED',
            'FALSE',
            '0',
          }.contains(status.toUpperCase())
        : readBool(json['isActive'], fallback: true);

    return SpecialtyModel(
      id: documentId ?? readString(json['id']),
      name: readStringForKeys(json, const ['name', 'TenChuyenKhoa']),
      description: readStringForKeys(json, const ['description', 'MoTa']),
      isActive: isActive,
      status: status.isEmpty ? (isActive ? 'ACTIVE' : 'INACTIVE') : status,
      imageUrl: readOptionalString(json['imageUrl'] ?? json['HinhAnh']),
      createdAt: readDateTime(json['createdAt'] ?? json['NgayTao']),
      updatedAt: readDateTime(json['updatedAt'] ?? json['NgayCapNhat']),
    );
  }

  factory SpecialtyModel.fromMap(
    Map<String, dynamic> map, {
    String? documentId,
  }) {
    return SpecialtyModel.fromJson(map, documentId: documentId);
  }

  factory SpecialtyModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return SpecialtyModel.fromJson(doc.data() ?? const {}, documentId: doc.id);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'isActive': isActive,
      'status': status,
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
    };
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'isActive': isActive,
      'status': status,
      if (imageUrl != null) 'imageUrl': imageUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
