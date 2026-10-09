import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/utils/model_value_parser.dart';
import '../../domain/entities/time_slot.dart';
export '../../domain/entities/time_slot.dart';

class TimeSlotModel extends TimeSlot {
  static const String collectionName = 'CA_KHAM';

  const TimeSlotModel({
    required super.id,
    required super.workScheduleId,
    super.doctorId = '',
    super.startTime,
    super.endTime,
    super.status = TimeSlotStatus.unknown,
    super.bookedCount,
    super.capacity,
    super.appointmentId,
    super.reservationCounts,
    super.createdAt,
    super.updatedAt,
  });

  factory TimeSlotModel.fromEntity(TimeSlot value) => TimeSlotModel(
    id: value.id,
    workScheduleId: value.workScheduleId,
    doctorId: value.doctorId,
    startTime: value.startTime,
    endTime: value.endTime,
    status: value.status,
    bookedCount: value.bookedCount,
    capacity: value.capacity,
    appointmentId: value.appointmentId,
    reservationCounts: value.reservationCounts,
    createdAt: value.createdAt,
    updatedAt: value.updatedAt,
  );

  factory TimeSlotModel.fromJson(
    Map<String, dynamic> json, {
    String? documentId,
  }) {
    return TimeSlotModel(
      id: documentId ?? readString(json['id']),
      workScheduleId: readReferenceId(json['workScheduleId']),
      doctorId: readReferenceId(json['doctorId']),
      startTime: readTimeString(json['startTime']),
      endTime: readTimeString(json['endTime']),
      status: TimeSlotStatus.fromValue(json['status']),
      bookedCount: _readOptionalInt(json['bookedCount']),
      capacity: _readOptionalInt(json['capacity']),
      appointmentId: readOptionalString(json['appointmentId']),
      reservationCounts: _readReservationCounts(json['reservationCounts']),
      createdAt: readDateTime(json['createdAt']),
      updatedAt: readDateTime(json['updatedAt']),
    );
  }

  factory TimeSlotModel.fromMap(
    Map<String, dynamic> map, {
    String? documentId,
  }) {
    return TimeSlotModel.fromJson(map, documentId: documentId);
  }

  factory TimeSlotModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return TimeSlotModel.fromJson(doc.data() ?? const {}, documentId: doc.id);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'workScheduleId': workScheduleId,
      'doctorId': doctorId,
      if (startTime != null) 'startTime': startTime,
      if (endTime != null) 'endTime': endTime,
      'status': status.firestoreValue,
      if (bookedCount != null) 'bookedCount': bookedCount,
      if (capacity != null) 'capacity': capacity,
      if (appointmentId != null) 'appointmentId': appointmentId,
      if (reservationCounts.isNotEmpty) 'reservationCounts': reservationCounts,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
    };
  }

  Map<String, dynamic> toFirestore() {
    return {
      'workScheduleId': workScheduleId,
      if (doctorId.isNotEmpty) 'doctorId': doctorId,
      if (startTime != null) 'startTime': startTime,
      if (endTime != null) 'endTime': endTime,
      'status': status.firestoreValue,
      if (bookedCount != null) 'bookedCount': bookedCount,
      if (capacity != null) 'capacity': capacity,
      if (appointmentId != null) 'appointmentId': appointmentId,
      if (reservationCounts.isNotEmpty) 'reservationCounts': reservationCounts,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  static int? _readOptionalInt(Object? value) {
    if (value == null) return null;
    return readInt(value);
  }

  static Map<String, int> _readReservationCounts(Object? value) {
    if (value is! Map) return const {};
    return Map.unmodifiable({
      for (final entry in value.entries)
        if (readString(entry.key).isNotEmpty)
          readString(entry.key): readInt(entry.value),
    });
  }
}
