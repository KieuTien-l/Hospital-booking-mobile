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
      case 'AVAILABLE_SLOT':
      case 'TRONG':
        return TimeSlotStatus.available;
      case 'BOOKED':
      case 'DA_DAT':
      case 'DADAT':
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
      id:
          documentId ??
          readStringForKeys(json, const ['id', 'Id', 'ID', 'MaCaKham']),
      workScheduleId: readReferenceIdForKeys(json, const [
        'MaLLV',
        'maLLV',
        'MaLichLamViec',
        'maLichLamViec',
        'LichLamViecId',
        'lichLamViecId',
        'workScheduleId',
      ]),
      doctorId: readReferenceIdForKeys(json, const [
        'MaBS',
        'maBS',
        'MaBacSi',
        'maBacSi',
        'BacSiId',
        'bacSiId',
        'doctorId',
      ]),
      startTime: readTimeStringForKeys(json, const [
        'GioBatDau',
        'gioBatDau',
        'ThoiGianBatDau',
        'startTime',
      ]),
      endTime: readTimeStringForKeys(json, const [
        'GioKetThuc',
        'gioKetThuc',
        'ThoiGianKetThuc',
        'endTime',
      ]),
      status: TimeSlotStatus.fromValue(
        readFirstValue(json, const ['TrangThai', 'trangThai', 'status']),
      ),
      bookedCount: _readOptionalInt(
        readFirstValue(json, const [
          'bookedCount',
          'SoLuongDaDat',
          'soLuongDaDat',
        ]),
      ),
      capacity: _readOptionalInt(
        readFirstValue(json, const [
          'capacity',
          'SoLuongToiDa',
          'soLuongToiDa',
        ]),
      ),
      appointmentId: readOptionalStringForKeys(json, const [
        'MaLichHen',
        'maLichHen',
        'LichHenId',
        'lichHenId',
        'appointmentId',
      ]),
      createdAt: readDateTime(
        readFirstValue(json, const ['createdAt', 'CreatedAt', 'NgayTao']),
      ),
      updatedAt: readDateTime(
        readFirstValue(json, const ['updatedAt', 'UpdatedAt', 'NgayCapNhat']),
      ),
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
