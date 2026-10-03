import 'package:cloud_firestore/cloud_firestore.dart';

import 'model_value_parser.dart';

enum TimeSlotStatus {
  available('AVAILABLE'),
  booked('BOOKED'),
  unavailable('UNAVAILABLE'),
  cancelled('CANCELLED'),
  unknown('UNKNOWN');

  const TimeSlotStatus(this.firestoreValue);

  final String firestoreValue;

  factory TimeSlotStatus.fromValue(Object? value) {
    switch (readString(value).toUpperCase()) {
      case 'AVAILABLE':
        return TimeSlotStatus.available;
      case 'BOOKED':
        return TimeSlotStatus.booked;
      case 'UNAVAILABLE':
      case 'BLOCKED':
        return TimeSlotStatus.unavailable;
      case 'CANCELLED':
      case 'CANCELED':
        return TimeSlotStatus.cancelled;
      default:
        return TimeSlotStatus.unknown;
    }
  }
}

class TimeSlot {
  static const String collectionName = 'CA_KHAM';

  const TimeSlot({
    required this.id,
    required this.workScheduleId,
    this.doctorId = '',
    this.startTime,
    this.endTime,
    this.status = TimeSlotStatus.unknown,
    this.bookedCount,
    this.capacity,
    this.appointmentId,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String workScheduleId;
  final String doctorId;
  final String? startTime;
  final String? endTime;
  final TimeSlotStatus status;
  final int? bookedCount;
  final int? capacity;
  final String? appointmentId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get maLichLamViec => workScheduleId;
  String get trangThai => status.firestoreValue;
  String? get maLichHen => appointmentId;
  bool get isAvailable =>
      status == TimeSlotStatus.available &&
      (capacity == null || (bookedCount ?? 0) < capacity!);

  factory TimeSlot.fromJson(Map<String, dynamic> json, {String? documentId}) {
    return TimeSlot(
      id: documentId ?? readString(json['id']),
      workScheduleId: readReferenceId(json['workScheduleId']),
      doctorId: readReferenceId(json['doctorId']),
      startTime: readTimeString(json['startTime']),
      endTime: readTimeString(json['endTime']),
      status: TimeSlotStatus.fromValue(json['status']),
      bookedCount: _readOptionalInt(json['bookedCount']),
      capacity: _readOptionalInt(json['capacity']),
      appointmentId: readOptionalString(json['appointmentId']),
      createdAt: readDateTime(json['createdAt']),
      updatedAt: readDateTime(json['updatedAt']),
    );
  }

  factory TimeSlot.fromMap(Map<String, dynamic> map, {String? documentId}) {
    return TimeSlot.fromJson(map, documentId: documentId);
  }

  factory TimeSlot.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    return TimeSlot.fromJson(doc.data() ?? const {}, documentId: doc.id);
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
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  static int? _readOptionalInt(Object? value) {
    if (value == null) return null;
    return readInt(value);
  }
}

typedef TimeSlotModel = TimeSlot;
