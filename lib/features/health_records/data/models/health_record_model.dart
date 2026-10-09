import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/utils/model_value_parser.dart';
import '../../domain/entities/health_record.dart';

class HealthRecordModel extends HealthRecord {
  const HealthRecordModel({
    required super.id,
    required super.patientId,
    required super.doctorId,
    required super.recordDate,
    required super.diagnosis,
    super.notes,
    super.prescription,
    super.attachments,
    super.createdAt,
    super.updatedAt,
  });

  factory HealthRecordModel.fromFirestore(DocumentSnapshot doc) {
    final raw = doc.data();
    final data = raw is Map<String, dynamic>
        ? raw
        : <String, dynamic>{};
    return HealthRecordModel(
      id: doc.id,
      patientId: readReferenceId(data['patientId']),
      doctorId: readReferenceId(data['doctorId']),
      recordDate: readDateTime(data['recordDate']) ?? DateTime.now(),
      diagnosis: readString(data['diagnosis']),
      notes: readOptionalString(data['notes']),
      prescription: readOptionalString(data['prescription']),
      attachments: _readAttachments(data['attachments']),
      createdAt: readDateTime(data['createdAt']),
      updatedAt: readDateTime(data['updatedAt']),
    );
  }

  static List<String> _readAttachments(Object? value) {
    if (value is! Iterable) return const [];
    return value
        .map(readOptionalString)
        .whereType<String>()
        .toList(growable: false);
  }
}

