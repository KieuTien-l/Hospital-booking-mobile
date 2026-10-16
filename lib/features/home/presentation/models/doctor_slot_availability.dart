import '../../../doctors/domain/entities/time_slot.dart';

enum DoctorSlotAvailability {
  available('Còn chỗ'),
  full('Đã đặt hết'),
  cancelled('Đã hủy'),
  unavailable('Tạm ngưng'),
  unknown('Chưa xác định số chỗ');

  const DoctorSlotAvailability(this.label);
  final String label;

  static DoctorSlotAvailability fromSlot(TimeSlot slot) {
    if (slot.status == TimeSlotStatus.cancelled) return cancelled;
    if (slot.status == TimeSlotStatus.unavailable) return unavailable;
    if (slot.status == TimeSlotStatus.unknown) return unknown;
    if (slot.status == TimeSlotStatus.booked) return full;
    final capacity = slot.capacity, booked = slot.bookedCount;
    if (capacity == null || capacity <= 0 || booked == null || booked < 0) {
      return unknown;
    }
    return booked >= capacity ? full : available;
  }
}
