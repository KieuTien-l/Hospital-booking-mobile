import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/utils/model_value_parser.dart';
import '../../domain/entities/appointment.dart';
export '../../domain/entities/appointment.dart';

class AppointmentModel extends Appointment {
  static const String collectionName = 'LICH_HEN';

  const AppointmentModel({
    required super.id,
    required super.patientId,
    required super.doctorId,
    required super.workScheduleId,
    required super.timeSlotId,
    super.specialtyId,
    super.appointmentDate,
    super.startTime,
    super.endTime,
    super.bookedAt,
    super.status = AppointmentStatus.unknown,
    super.reason,
    super.note,
    super.cancellationReason,
    super.symptoms,
    super.peopleCount = 1,
    super.queueNumber,
    super.checkInTime,
    super.qrCode,
    super.createdAt,
    super.updatedAt,
  });

  factory AppointmentModel.fromEntity(Appointment value) => AppointmentModel(
    id: value.id,
    patientId: value.patientId,
    doctorId: value.doctorId,
    workScheduleId: value.workScheduleId,
    timeSlotId: value.timeSlotId,
    specialtyId: value.specialtyId,
    appointmentDate: value.appointmentDate,
    startTime: value.startTime,
    endTime: value.endTime,
    bookedAt: value.bookedAt,
    status: value.status,
    reason: value.reason,
    note: value.note,
    cancellationReason: value.cancellationReason,
    symptoms: value.symptoms,
    peopleCount: value.peopleCount,
    queueNumber: value.queueNumber,
    checkInTime: value.checkInTime,
    qrCode: value.qrCode,
    createdAt: value.createdAt,
    updatedAt: value.updatedAt,
  );

  factory AppointmentModel.fromJson(
    Map<String, dynamic> json, {
    String? documentId,
  }) {
    return AppointmentModel(
      id: documentId ?? readString(json['id']),
      patientId: readReferenceId(json['patientId']),
      doctorId: readReferenceId(json['doctorId']),
      workScheduleId: readReferenceId(json['workScheduleId']),
      timeSlotId: readReferenceId(json['timeSlotId']),
      specialtyId: readOptionalString(json['specialtyId']),
      appointmentDate: readDateTime(json['appointmentDate']),
      startTime: readTimeString(json['startTime']),
      endTime: readTimeString(json['endTime']),
      bookedAt: readDateTime(json['bookedAt']),
      status: AppointmentStatus.fromValue(json['status']),
      reason: readOptionalString(json['reason']),
      note: readOptionalString(json['note']),
      cancellationReason: readOptionalString(json['cancellationReason']),
      symptoms: readOptionalString(json['symptoms']),
      peopleCount: readInt(json['peopleCount'], fallback: 1),
      queueNumber: _readOptionalInt(json['queueNumber']),
      checkInTime: readDateTime(json['checkInTime']),
      qrCode: readOptionalString(json['qrCode']),
      createdAt: readDateTime(json['createdAt']),
      updatedAt: readDateTime(json['updatedAt']),
    );
  }

  factory AppointmentModel.fromMap(
    Map<String, dynamic> map, {
    String? documentId,
  }) {
    return AppointmentModel.fromJson(map, documentId: documentId);
  }

  factory AppointmentModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return AppointmentModel.fromJson(
      doc.data() ?? const {},
      documentId: doc.id,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patientId': patientId,
      'doctorId': doctorId,
      'workScheduleId': workScheduleId,
      'timeSlotId': timeSlotId,
      if (specialtyId != null) 'specialtyId': specialtyId,
      if (appointmentDate != null)
        'appointmentDate': appointmentDate!.toIso8601String(),
      if (startTime != null) 'startTime': startTime,
      if (endTime != null) 'endTime': endTime,
      if (bookedAt != null) 'bookedAt': bookedAt!.toIso8601String(),
      'status': status.firestoreValue,
      if (reason != null) 'reason': reason,
      if (note != null) 'note': note,
      if (cancellationReason != null) 'cancellationReason': cancellationReason,
      if (symptoms != null) 'symptoms': symptoms,
      'peopleCount': peopleCount,
      if (queueNumber != null) 'queueNumber': queueNumber,
      if (checkInTime != null) 'checkInTime': checkInTime!.toIso8601String(),
      if (qrCode != null) 'qrCode': qrCode,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
    };
  }

  Map<String, dynamic> toFirestore() {
    return {
      'patientId': patientId,
      'doctorId': doctorId,
      'workScheduleId': workScheduleId,
      'timeSlotId': timeSlotId,
      if (specialtyId != null) 'specialtyId': specialtyId,
      if (appointmentDate != null) 'appointmentDate': appointmentDate,
      if (startTime != null) 'startTime': startTime,
      if (endTime != null) 'endTime': endTime,
      if (bookedAt != null) 'bookedAt': bookedAt,
      'status': status.firestoreValue,
      if (reason != null) 'reason': reason,
      if (note != null) 'note': note,
      if (cancellationReason != null) 'cancellationReason': cancellationReason,
      if (symptoms != null) 'symptoms': symptoms,
      'peopleCount': peopleCount,
      if (queueNumber != null) 'queueNumber': queueNumber,
      if (checkInTime != null) 'checkInTime': checkInTime,
      if (qrCode != null) 'qrCode': qrCode,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  static int? _readOptionalInt(Object? value) {
    if (value == null) return null;
    return readInt(value);
  }
}
