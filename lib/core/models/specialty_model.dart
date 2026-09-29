import 'package:cloud_firestore/cloud_firestore.dart';

import 'model_value_parser.dart';

class Specialty {
  static const String collectionName = 'CHUYEN_KHOA';

  const Specialty({
    required this.id,
    required this.name,
    required this.description,
    required this.isActive,
    this.status = 'ACTIVE',
    this.imageUrl,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String description;
  final bool isActive;
  final String status;
  final String? imageUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get tenChuyenKhoa => name;
  String get moTa => description;
  String? get hinhAnh => imageUrl;
  String get trangThai => status;

  factory Specialty.fromJson(Map<String, dynamic> json, {String? documentId}) {
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

    return Specialty(
      id: documentId ?? readStringForKeys(json, const ['id', 'Id', 'ID']),
      name: readStringForKeys(json, const [
        'TenChuyenKhoa',
        'tenChuyenKhoa',
        'name',
        'Name',
      ]),
      description: readStringForKeys(json, const [
        'MoTa',
        'moTa',
        'description',
        'Description',
      ]),
      isActive: isActive,
      status: status.isEmpty ? (isActive ? 'ACTIVE' : 'INACTIVE') : status,
      imageUrl: readOptionalStringForKeys(json, const [
        'HinhAnh',
        'hinhAnh',
        'imageUrl',
        'ImageUrl',
      ]),
      createdAt: readDateTime(
        readFirstValue(json, const ['createdAt', 'CreatedAt', 'NgayTao']),
      ),
      updatedAt: readDateTime(
        readFirstValue(json, const ['updatedAt', 'UpdatedAt', 'NgayCapNhat']),
      ),
    );
  }

  factory Specialty.fromMap(Map<String, dynamic> map, {String? documentId}) {
    return Specialty.fromJson(map, documentId: documentId);
  }

  factory Specialty.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    return Specialty.fromJson(doc.data() ?? const {}, documentId: doc.id);
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

typedef SpecialtyModel = Specialty;
