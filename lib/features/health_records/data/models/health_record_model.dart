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
    super.recordType,
    super.documentCategory,
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
      recordType: _recordType(readOptionalString(data['recordType'])),
      documentCategory: _documentCategory(
        readOptionalString(data['documentCategory']),
      ),
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

  static String _recordType(String? value) {
    switch (value?.trim().toUpperCase()) {
      case HealthRecordType.inpatient:
        return HealthRecordType.inpatient;
      case HealthRecordType.checkup:
        return HealthRecordType.checkup;
      case HealthRecordType.outpatient:
      default:
        // Existing documents were created before this field was introduced.
        // They represent ordinary visits, so keep them visible in "Khám bệnh".
        return HealthRecordType.outpatient;
    }
  }

  static String? _documentCategory(String? value) {
    switch (value?.trim().toUpperCase()) {
      case HealthRecordDocumentCategory.prescription:
        return HealthRecordDocumentCategory.prescription;
      case HealthRecordDocumentCategory.order:
        return HealthRecordDocumentCategory.order;
      case HealthRecordDocumentCategory.certificate:
        return HealthRecordDocumentCategory.certificate;
      default:
        return null;
    }
  }
}

