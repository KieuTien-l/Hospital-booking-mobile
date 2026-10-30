import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/utils/model_value_parser.dart';
import '../../domain/entities/test_result.dart';

class TestResultModel extends TestResult {
  const TestResultModel({
    required super.id,
    required super.patientId,
    required super.testName,
    required super.resultDescription,
    required super.testDate,
    super.resultType,
    super.patientCode,
    super.appointmentId,
    super.examinationId,
    super.conclusion,
    super.referenceRange,
    super.doctorName,
    super.attachmentUrl,
  });

  static const String collectionName = 'KET_QUA_CLS';

  factory TestResultModel.fromFirestore(DocumentSnapshot doc) {
    final raw = doc.data();
    final data = raw is Map<String, dynamic> ? raw : <String, dynamic>{};
    final testDate = readDateTime(
      readFirstValue(data, const ['testDate', 'resultDate', 'NgayTraKetQua']),
    );
    if (testDate == null) {
      throw const FormatException(
        'Kết quả cận lâm sàng thiếu hoặc có ngày trả kết quả không hợp lệ.',
      );
    }
    return TestResultModel(
      id: doc.id,
      patientId: readReferenceIdForKeys(data, const ['patientId', 'MaBN']),
      testName: readStringForKeys(data, const ['testName', 'TenXetNghiem']),
      resultDescription: readStringForKeys(data, const [
        'resultDescription',
        'result',
        'KetQua',
      ]),
      testDate: testDate,
      resultType: readStringForKeys(data, const [
        'resultType',
        'testType',
        'LoaiKetQua',
      ], fallback: 'Khác'),
      patientCode: readOptionalString(data['patientCode']),
      appointmentId: readOptionalString(data['appointmentId']),
      examinationId: readOptionalString(data['examinationId']),
      conclusion: readOptionalStringForKeys(data, const [
        'conclusion',
        'KetLuan',
      ]),
      referenceRange: readOptionalStringForKeys(data, const [
        'referenceRange',
        'ChiSoThamChieu',
      ]),
      doctorName: readOptionalStringForKeys(data, const [
        'doctorName',
        'TenBacSi',
      ]),
      attachmentUrl: readOptionalStringForKeys(data, const [
        'attachmentUrl',
        'fileUrl',
        'TepDinhKem',
      ]),
    );
  }
}
