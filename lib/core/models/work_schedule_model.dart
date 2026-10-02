import 'package:cloud_firestore/cloud_firestore.dart';

import 'model_value_parser.dart';

class WorkSchedule {
  static const String collectionName = 'LICH_LAM_VIEC';

  const WorkSchedule({
    required this.id,
    required this.doctorId,
    this.workDate,
    this.startTime,
    this.endTime,
    this.status = 'ACTIVE',
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String doctorId;
  final DateTime? workDate;
  final String? startTime;
  final String? endTime;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get maBacSi => doctorId;
  String get trangThai => status;

  factory WorkSchedule.fromJson(
    Map<String, dynamic> json, {
    String? documentId,
  }) {
    return WorkSchedule(
      id: documentId ?? readString(json['id']),
      doctorId: readReferenceId(json['doctorId']),
      workDate: readDateTime(json['workDate']),
      startTime: readTimeString(json['startTime']),
      endTime: readTimeString(json['endTime']),
      status: readString(json['status'], fallback: 'ACTIVE'),
      createdAt: readDateTime(json['createdAt']),
      updatedAt: readDateTime(json['updatedAt']),
    );
  }

  factory WorkSchedule.fromMap(Map<String, dynamic> map, {String? documentId}) {
    return WorkSchedule.fromJson(map, documentId: documentId);
  }

  factory WorkSchedule.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return WorkSchedule.fromJson(doc.data() ?? const {}, documentId: doc.id);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'doctorId': doctorId,
      if (workDate != null) 'workDate': workDate!.toIso8601String(),
      if (startTime != null) 'startTime': startTime,
      if (endTime != null) 'endTime': endTime,
      'status': status,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
    };
  }

  Map<String, dynamic> toFirestore() {
    return {
      'doctorId': doctorId,
      if (workDate != null) 'workDate': workDate,
      if (startTime != null) 'startTime': startTime,
      if (endTime != null) 'endTime': endTime,
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

typedef WorkScheduleModel = WorkSchedule;
