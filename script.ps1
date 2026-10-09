$model = "import 'package:cloud_firestore/cloud_firestore.dart';
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
    final data = doc.data() as Map<String, dynamic>;
    return HealthRecordModel(
      id: doc.id,
      patientId: data['patientId'] ?? '',
      doctorId: data['doctorId'] ?? '',
      recordDate: (data['recordDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      diagnosis: data['diagnosis'] ?? '',
      notes: data['notes'],
      prescription: data['prescription'],
      attachments: List<String>.from(data['attachments'] ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}
"

$repoDomain = "import '../entities/health_record.dart';

abstract class HealthRecordRepository {
  Future<List<HealthRecord>> getHealthRecordsByPatient(String patientId);
}
"

$datasource = "import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/health_record_model.dart';

class HealthRecordFirebaseDatasource {
  HealthRecordFirebaseDatasource(this._firestore);
  final FirebaseFirestore _firestore;

  Future<List<HealthRecordModel>> getHealthRecordsByPatient(String patientId) async {
    final query = await _firestore
        .collection('health_records')
        .where('patientId', isEqualTo: patientId)
        .orderBy('recordDate', descending: true)
        .get();
    return query.docs.map((doc) => HealthRecordModel.fromFirestore(doc)).toList();
  }
}
"

$repoImpl = "import '../../domain/entities/health_record.dart';
import '../../domain/repositories/health_record_repository.dart';
import '../datasources/health_record_firebase_datasource.dart';

class HealthRecordRepositoryImpl implements HealthRecordRepository {
  HealthRecordRepositoryImpl(this._datasource);
  final HealthRecordFirebaseDatasource _datasource;

  @override
  Future<List<HealthRecord>> getHealthRecordsByPatient(String patientId) =>
      _datasource.getHealthRecordsByPatient(patientId);
}
"

$controller = "import '../../../../core/state/view_state.dart';
import '../../domain/entities/health_record.dart';
import '../../domain/repositories/health_record_repository.dart';

class HealthRecordController extends ViewStateController {
  HealthRecordController(this._repository);
  final HealthRecordRepository _repository;
  
  List<HealthRecord> _records = const [];
  List<HealthRecord> get records => _records;

  Future<void> loadRecords(String patientId) async {
    _records = const [];
    final token = beginRequest();
    try {
      final values = await _repository.getHealthRecordsByPatient(patientId);
      if (!isCurrent(token)) return;
      _records = List.unmodifiable(values);
      setState(values.isEmpty ? ViewState.empty : ViewState.success);
    } catch (error) {
      if (isCurrent(token)) setState(ViewState.error, error);
    }
  }
}
"

Set-Content -Path lib/features/health_records/data/models/health_record_model.dart -Value $model
Set-Content -Path lib/features/health_records/domain/repositories/health_record_repository.dart -Value $repoDomain
Set-Content -Path lib/features/health_records/data/datasources/health_record_firebase_datasource.dart -Value $datasource
Set-Content -Path lib/features/health_records/data/repositories/health_record_repository_impl.dart -Value $repoImpl
Set-Content -Path lib/features/health_records/presentation/controllers/health_record_controller.dart -Value $controller
