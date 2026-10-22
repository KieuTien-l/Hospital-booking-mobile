import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/utils/model_value_parser.dart';
import '../../domain/entities/doctor_workspace.dart';

class DoctorReportModel {
  static const collectionName = 'YEU_CAU_BAC_SI';

  static DoctorReport fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    final date = readDateTime(data['date']);
    if (date == null) {
      throw const FormatException('Yêu cầu thiếu ngày liên quan.');
    }
    return DoctorReport(
      id: doc.id,
      type: readString(data['type']),
      date: date,
      reason: readString(data['reason']),
      description: readOptionalString(data['description']),
      senderId: readOptionalString(data['senderId']),
      doctorId: readReferenceId(data['doctorId']),
      scheduleId: readReferenceId(data['scheduleId']),
      status: switch (data['status']) {
        'PENDING' => DoctorReportStatus.pending,
        'APPROVED' => DoctorReportStatus.approved,
        'REJECTED' => DoctorReportStatus.rejected,
        'RESOLVED' => DoctorReportStatus.resolved,
        _ => DoctorReportStatus.unknown,
      },
      adminResponse: readOptionalString(data['adminResponse']),
      reviewedBy: readOptionalString(data['reviewedBy']),
      createdAt: readDateTime(data['createdAt']),
      reviewedAt: readDateTime(data['reviewedAt']),
    );
  }
}
