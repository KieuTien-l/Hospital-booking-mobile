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
    super.patientCode,
    super.appointmentId,
    super.examinationId,
    super.prescription,
    super.medicines,
    super.attachments,
    super.recordType,
    super.documentCategory,
    super.createdAt,
    super.updatedAt,
  });

  factory HealthRecordModel.fromFirestore(DocumentSnapshot doc) {
    final raw = doc.data();
    final data = raw is Map<String, dynamic> ? raw : <String, dynamic>{};
    final recordDate = readDateTime(data['recordDate']);
    if (recordDate == null) {
      throw const FormatException(
        'Hồ sơ sức khỏe thiếu hoặc có ngày khám không hợp lệ.',
      );
    }
    return HealthRecordModel(
      id: doc.id,
      patientId: readReferenceId(data['patientId']),
      doctorId: readReferenceId(data['doctorId']),
      recordDate: recordDate,
      diagnosis: readString(data['diagnosis']),
      notes: readOptionalString(data['notes']),
      patientCode: readOptionalString(data['patientCode']),
      appointmentId: readOptionalString(data['appointmentId']),
      examinationId: readOptionalString(data['examinationId']),
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

  /// Maps a real prescription document into the patient history list.  This
  /// retains the existing screen/controller while prescriptions now live in
  /// their own `DON_THUOC` collection.
  factory HealthRecordModel.fromPrescriptionFirestore(DocumentSnapshot doc) {
    final raw = doc.data();
    final data = raw is Map<String, dynamic> ? raw : <String, dynamic>{};
    final recordDate =
        readDateTime(data['issuedAt']) ?? readDateTime(data['createdAt']);
    if (recordDate == null) {
      throw const FormatException('Đơn thuốc thiếu ngày kê đơn hợp lệ.');
    }
    return HealthRecordModel(
      id: 'prescription_${doc.id}',
      patientId: readReferenceId(data['patientId']),
      doctorId: readReferenceId(data['doctorId']),
      recordDate: recordDate,
      diagnosis: readOptionalString(data['diagnosis']) ?? 'Đơn thuốc',
      notes: readOptionalString(data['notes']),
      patientCode: readOptionalString(data['patientCode']),
      appointmentId: readOptionalString(data['appointmentId']),
      examinationId: readOptionalString(data['examinationId']),
      prescription: _prescriptionText(data),
      medicines: _readMedicines(data['medicines']),
      recordType: HealthRecordType.outpatient,
      documentCategory: HealthRecordDocumentCategory.prescription,
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

  static List<HealthRecordMedicine> _readMedicines(Object? value) {
    if (value is! Iterable) return const [];
    return value
        .whereType<Map>()
        .map((item) {
          String text(String key) => readOptionalString(item[key]) ?? '';
          final name = text('name');
          if (name.isEmpty) return null;
          return HealthRecordMedicine(
            name: name,
            strength: text('strength'),
            quantity: text('quantity'),
            dose: text('dose'),
            frequency: text('frequency'),
            duration: text('duration'),
            instructions: text('instructions'),
          );
        })
        .whereType<HealthRecordMedicine>()
        .toList(growable: false);
  }

  static String? _prescriptionText(Map<String, dynamic> data) {
    final medicines = data['medicines'];
    if (medicines is List) {
      final formatted = medicines
          .whereType<Map>()
          .map((item) {
            String text(String key) => readOptionalString(item[key]) ?? '';
            final name = text('name');
            if (name.isEmpty) return '';
            return [
              name,
              if (text('strength').isNotEmpty) 'Hàm lượng: ${text('strength')}',
              if (text('quantity').isNotEmpty) 'Số lượng: ${text('quantity')}',
              if (text('dose').isNotEmpty) 'Liều mỗi lần: ${text('dose')}',
              if (text('frequency').isNotEmpty)
                'Tần suất: ${text('frequency')}',
              if (text('duration').isNotEmpty)
                'Thời gian dùng: ${text('duration')}',
              if (text('instructions').isNotEmpty)
                'Lưu ý: ${text('instructions')}',
            ].join('\n');
          })
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
      if (formatted.isNotEmpty) return formatted.join('\n\n');
    }
    final instructions = readOptionalString(data['instructions']);
    if (instructions == null || instructions.isEmpty) return instructions;
    final parts = instructions.split(RegExp(r'\s+—\s+'));
    if (parts.length < 2) return instructions;
    final hasQuantity = parts.length >= 6;
    final details = <String>[
      if (parts.length > 1) 'Hàm lượng: ${parts[1]}',
      if (hasQuantity) 'Số lượng: ${parts[2]}',
      if (parts.length > (hasQuantity ? 3 : 2))
        'Liều mỗi lần: ${parts[hasQuantity ? 3 : 2]}',
      if (parts.length > (hasQuantity ? 4 : 3))
        'Tần suất: ${parts[hasQuantity ? 4 : 3]}',
      if (parts.length > (hasQuantity ? 5 : 4))
        'Thời gian dùng: ${parts[hasQuantity ? 5 : 4]}',
      if (parts.length > (hasQuantity ? 6 : 5))
        'Lưu ý: ${parts.skip(hasQuantity ? 6 : 5).join(' — ')}',
    ];
    return '${parts.first}\n${details.join('\n')}';
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
