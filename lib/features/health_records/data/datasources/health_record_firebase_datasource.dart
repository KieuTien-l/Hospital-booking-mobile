import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/health_record_model.dart';

class HealthRecordFirebaseDatasource {
  HealthRecordFirebaseDatasource(this._firestore);
  final FirebaseFirestore _firestore;

  static const String collectionName = 'HO_SO_SUC_KHOE';

  Future<List<HealthRecordModel>> getHealthRecordsByPatient(
    String patientId,
  ) async {
    final values = await Future.wait([
      _firestore
          .collection(collectionName)
          .where('patientId', isEqualTo: patientId)
          .get(),
      _firestore
          .collection('DON_THUOC')
          .where('patientId', isEqualTo: patientId)
          .where('status', isEqualTo: 'ISSUED')
          .get(),
    ]);
    final prescriptionAppointmentIds = values[1].docs
        .map((doc) => doc.data()['appointmentId'])
        .whereType<String>()
        .toSet();
    final records = [
      // Keep legacy embedded prescriptions visible until the Worker issues a
      // matching DON_THUOC document. Once it does, the real prescription is
      // the single source shown to the patient, preventing duplicate cards.
      ...values[0].docs
          .map((doc) => HealthRecordModel.fromFirestore(doc))
          .where(
            (record) =>
                (record.prescription?.trim().isEmpty ?? true) ||
                !prescriptionAppointmentIds.contains(record.appointmentId),
          ),
      ...values[1].docs.map(
        (doc) => HealthRecordModel.fromPrescriptionFirestore(doc),
      ),
    ];
    // Sort locally so reading a patient's records does not require a
    // composite Firestore index.
    records.sort((a, b) => b.recordDate.compareTo(a.recordDate));
    return List.unmodifiable(records);
  }
}
