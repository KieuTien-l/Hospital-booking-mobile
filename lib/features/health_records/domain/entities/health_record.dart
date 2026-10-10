abstract final class HealthRecordType {
  static const outpatient = 'OUTPATIENT';
  static const inpatient = 'INPATIENT';
  static const checkup = 'CHECKUP';
}

abstract final class HealthRecordDocumentCategory {
  static const prescription = 'PRESCRIPTION';
  static const order = 'ORDER';
  static const certificate = 'CERTIFICATE';
}

class HealthRecord {
  const HealthRecord({
    required this.id,
    required this.patientId,
    required this.doctorId,
    required this.recordDate,
    required this.diagnosis,
    this.notes,
    this.prescription,
    this.attachments = const [],
    this.recordType = HealthRecordType.outpatient,
    this.documentCategory,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String patientId;
  final String doctorId;
  final DateTime recordDate;
  final String diagnosis;
  final String? notes;
  final String? prescription;
  final List<String> attachments;
  final String recordType;
  final String? documentCategory;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}
