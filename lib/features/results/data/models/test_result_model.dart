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
    super.attachmentUrl,
  });

  static const String collectionName = 'KET_QUA_CLS';

  factory TestResultModel.fromFirestore(DocumentSnapshot doc) {
    final raw = doc.data();
    final data = raw is Map<String, dynamic>
        ? raw
        : <String, dynamic>{};
    return TestResultModel(
      id: doc.id,
      patientId: readReferenceId(data['patientId']),
      testName: readString(data['testName']),
      resultDescription: readString(data['resultDescription']),
      testDate: readDateTime(data['testDate']) ?? DateTime.now(),
      attachmentUrl: readOptionalString(data['attachmentUrl']),
    );
  }
}

