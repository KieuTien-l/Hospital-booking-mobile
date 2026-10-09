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
  final DateTime? createdAt;
  final DateTime? updatedAt;
}
