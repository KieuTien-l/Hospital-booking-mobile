import 'package:cloud_firestore/cloud_firestore.dart';

import 'model_value_parser.dart';

class SpecialtyModel {
  const SpecialtyModel({
    required this.id,
    required this.name,
    required this.description,
    required this.isActive,
    this.imageUrl,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String description;
  final bool isActive;
  final String? imageUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory SpecialtyModel.fromJson(
    Map<String, dynamic> json, {
    String? documentId,
  }) {
    final imageUrl = readString(json['imageUrl']);
    return SpecialtyModel(
      id: documentId ?? readString(json['id']),
      name: readString(json['name']),
      description: readString(json['description']),
      isActive: readBool(json['isActive'], fallback: true),
      imageUrl: imageUrl.isEmpty ? null : imageUrl,
      createdAt: readDateTime(json['createdAt']),
      updatedAt: readDateTime(json['updatedAt']),
    );
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
      if (imageUrl != null) 'imageUrl': imageUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
