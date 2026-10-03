import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/utils/model_value_parser.dart';
import '../../domain/entities/work_schedule.dart';
export '../../domain/entities/work_schedule.dart';

class WorkScheduleModel extends WorkSchedule {
  static const String collectionName = 'LICH_LAM_VIEC';

  const WorkScheduleModel({
    required super.id,
    required super.doctorId,
    super.workDate,
    super.startTime,
    super.endTime,
    super.status = 'ACTIVE',
    super.createdAt,
    super.updatedAt,
  });

  factory WorkScheduleModel.fromEntity(WorkSchedule value) => WorkScheduleModel(
    id: value.id,
    doctorId: value.doctorId,
    workDate: value.workDate,
    startTime: value.startTime,
    endTime: value.endTime,
    status: value.status,
    createdAt: value.createdAt,
    updatedAt: value.updatedAt,
  );

  factory WorkScheduleModel.fromJson(
    Map<String, dynamic> json, {
    String? documentId,
  }) {
    return WorkScheduleModel(
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

  factory WorkScheduleModel.fromMap(
    Map<String, dynamic> map, {
    String? documentId,
  }) {
    return WorkScheduleModel.fromJson(map, documentId: documentId);
  }

  factory WorkScheduleModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return WorkScheduleModel.fromJson(
      doc.data() ?? const {},
      documentId: doc.id,
    );
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
