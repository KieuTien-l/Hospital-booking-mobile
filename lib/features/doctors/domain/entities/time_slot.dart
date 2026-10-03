enum TimeSlotStatus {
  available('AVAILABLE'),
  booked('BOOKED'),
  unavailable('UNAVAILABLE'),
  cancelled('CANCELLED'),
  unknown('UNKNOWN');

  const TimeSlotStatus(this.firestoreValue);

  final String firestoreValue;

  factory TimeSlotStatus.fromValue(Object? value) {
    switch ((value?.toString().trim() ?? '').toUpperCase()) {
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
}
