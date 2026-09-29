import 'package:cloud_firestore/cloud_firestore.dart';

import 'model_value_parser.dart';

enum AppointmentStatus {
  pending('PENDING'),
  confirmed('CONFIRMED'),
  completed('COMPLETED'),
  cancelled('CANCELLED'),
  noShow('NO_SHOW'),
  unknown('UNKNOWN');

  const AppointmentStatus(this.firestoreValue);

  final String firestoreValue;

  factory AppointmentStatus.fromValue(Object? value) {
    switch (readString(value).toUpperCase()) {
      case 'PENDING':
      case 'CHO_XAC_NHAN':
        return AppointmentStatus.pending;
      case 'CONFIRMED':
      case 'DA_XAC_NHAN':
        return AppointmentStatus.confirmed;
      case 'COMPLETED':
      case 'HOAN_THANH':
        return AppointmentStatus.completed;
      case 'CANCELLED':
      case 'CANCELED':
      case 'DA_HUY':
        return AppointmentStatus.cancelled;
      case 'NO_SHOW':
        return AppointmentStatus.noShow;
      default:
        return AppointmentStatus.unknown;
    }
  }
}

class Appointment {
  static const String collectionName = 'LICH_HEN';

  const Appointment({
    required this.id,
    required this.patientId,
    required this.doctorId,
    required this.workScheduleId,
    required this.timeSlotId,
    this.specialtyId,
    this.appointmentDate,
    this.startTime,
    this.endTime,
    this.bookedAt,
    this.status = AppointmentStatus.unknown,
    this.reason,
    this.note,
    this.cancellationReason,
    this.symptoms,
    this.peopleCount = 1,
    this.queueNumber,
    this.checkInTime,
    this.qrCode,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String patientId;
  final String doctorId;
  final String workScheduleId;
  final String timeSlotId;
  final String? specialtyId;
  final DateTime? appointmentDate;
  final String? startTime;
  final String? endTime;
  final DateTime? bookedAt;
  final AppointmentStatus status;
  final String? reason;
  final String? note;
  final String? cancellationReason;
  final String? symptoms;
  final int peopleCount;
  final int? queueNumber;
  final DateTime? checkInTime;
  final String? qrCode;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get maBenhNhan => patientId;
  String get maBacSi => doctorId;
  String get maLichLamViec => workScheduleId;
  String get maCaKham => timeSlotId;
  String get trangThai => status.firestoreValue;

  factory Appointment.fromJson(
    Map<String, dynamic> json, {
    String? documentId,
  }) {
    return Appointment(
      id:
          documentId ??
          readStringForKeys(json, const ['id', 'Id', 'ID', 'MaLichHen']),
      patientId: readReferenceIdForKeys(json, const [
        'MyBN',
        'myBN',
        'MaBN',
        'maBN',
        'MaBenhNhan',
        'maBenhNhan',
        'BenhNhanId',
        'benhNhanId',
        'patientId',
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
      workScheduleId: readReferenceIdForKeys(json, const [
        'MaLLV',
        'maLLV',
        'MaLichLamViec',
        'maLichLamViec',
        'LichLamViecId',
        'lichLamViecId',
        'workScheduleId',
      ]),
      timeSlotId: readReferenceIdForKeys(json, const [
        'Maca',
        'maca',
        'MaCa',
        'maCa',
        'MaCaKham',
        'maCaKham',
        'CaKhamId',
        'caKhamId',
        'timeSlotId',
      ]),
      specialtyId: readOptionalStringForKeys(json, const [
        'MaCK',
        'maCK',
        'MaChuyenKhoa',
        'maChuyenKhoa',
        'specialtyId',
      ]),
      appointmentDate: readDateTime(
        readFirstValue(json, const [
          'NgayKham',
          'ngayKham',
          'NgayHen',
          'ngayHen',
          'appointmentDate',
        ]),
      ),
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
      bookedAt: readDateTime(
        readFirstValue(json, const ['NgayDat', 'ngayDat', 'bookedAt']),
      ),
      status: AppointmentStatus.fromValue(
        readFirstValue(json, const ['TrangThai', 'trangThai', 'status']),
      ),
      reason: readOptionalStringForKeys(json, const [
        'LyDoKham',
        'lyDoKham',
        'reason',
      ]),
      note: readOptionalStringForKeys(json, const ['GhiChu', 'ghiChu', 'note']),
      cancellationReason: readOptionalStringForKeys(json, const [
        'LyDoHuy',
        'lyDoHuy',
        'cancellationReason',
      ]),
      symptoms: readOptionalStringForKeys(json, const [
        'TrieuChung',
        'trieuChung',
        'symptoms',
      ]),
      peopleCount: readInt(
        readFirstValue(json, const [
          'peopleCount',
          'SoNguoiKham',
          'soNguoiKham',
        ]),
        fallback: 1,
      ),
      queueNumber: _readOptionalInt(
        readFirstValue(json, const [
          'queueNumber',
          'SoThuTuKham',
          'soThuTuKham',
        ]),
      ),
      checkInTime: readDateTime(
        readFirstValue(json, const [
          'ThoiGianCheckIn',
          'thoiGianCheckIn',
          'checkInTime',
        ]),
      ),
      qrCode: readOptionalStringForKeys(json, const ['MaQR', 'maQR', 'qrCode']),
      createdAt: readDateTime(
        readFirstValue(json, const ['createdAt', 'CreatedAt', 'NgayTao']),
      ),
      updatedAt: readDateTime(
        readFirstValue(json, const ['updatedAt', 'UpdatedAt', 'NgayCapNhat']),
      ),
    );
  }

  factory Appointment.fromMap(Map<String, dynamic> map, {String? documentId}) {
    return Appointment.fromJson(map, documentId: documentId);
  }

  factory Appointment.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return Appointment.fromJson(doc.data() ?? const {}, documentId: doc.id);
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

typedef AppointmentModel = Appointment;
