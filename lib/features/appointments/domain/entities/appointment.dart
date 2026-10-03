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
    switch ((value?.toString().trim() ?? '').toUpperCase()) {
      case 'PENDING':
        return AppointmentStatus.pending;
      case 'CONFIRMED':
        return AppointmentStatus.confirmed;
      case 'COMPLETED':
        return AppointmentStatus.completed;
      case 'CANCELLED':
      case 'CANCELED':
        return AppointmentStatus.cancelled;
      case 'NO_SHOW':
        return AppointmentStatus.noShow;
      default:
        return AppointmentStatus.unknown;
    }
  }
}

class Appointment {
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
}
