import '../../../appointments/domain/entities/appointment.dart';
import '../../../doctors/domain/entities/doctor.dart';
import '../../../doctors/domain/entities/time_slot.dart';
import '../../../doctors/domain/entities/work_schedule.dart';

class DoctorBooking {
  const DoctorBooking({
    required this.appointment,
    required this.patientName,
    this.birthYear,
    this.gender,
  });
  final Appointment appointment;
  final String patientName;
  final int? birthYear;
  final String? gender;
}

class DoctorBookingTotals {
  const DoctorBookingTotals({
    this.booked = 0,
    this.completed = 0,
    this.waiting = 0,
    this.pending = 0,
  });
  factory DoctorBookingTotals.fromBookings(Iterable<DoctorBooking> bookings) {
    var total = 0, completed = 0, waiting = 0, pending = 0;
    for (final booking in bookings) {
      final appointment = booking.appointment;
      final count = appointment.peopleCount;
      if (count < 1 ||
          appointment.status == AppointmentStatus.cancelled ||
          appointment.status == AppointmentStatus.unknown) {
        continue;
      }
      total += count;
      switch (appointment.status) {
        case AppointmentStatus.completed:
          completed += count;
        case AppointmentStatus.confirmed:
          waiting += count;
        case AppointmentStatus.pending:
          pending += count;
        default:
          break;
      }
    }
    return DoctorBookingTotals(
      booked: total,
      completed: completed,
      waiting: waiting,
      pending: pending,
    );
  }
  final int booked, completed, waiting, pending;
}

class DoctorDayData {
  DoctorDayData({
    required this.doctor,
    required this.date,
    required List<WorkSchedule> schedules,
    required List<TimeSlot> slots,
    required List<DoctorBooking> bookings,
  }) : schedules = List.unmodifiable(schedules),
       slots = List.unmodifiable(slots),
       bookings = List.unmodifiable(bookings);
  final Doctor doctor;
  final DateTime date;
  final List<WorkSchedule> schedules;
  final List<TimeSlot> slots;
  final List<DoctorBooking> bookings;
  DoctorBookingTotals get totals => DoctorBookingTotals.fromBookings(bookings);
}

class DoctorReportDraft {
  const DoctorReportDraft({
    required this.type,
    required this.scheduleId,
    required this.date,
    required this.reason,
    required this.description,
    required this.requestId,
  });
  final String type, scheduleId, reason, description, requestId;
  final DateTime date;
}

enum DoctorReportStatus { pending, approved, rejected, resolved, unknown }

class DoctorReport {
  const DoctorReport({
    required this.id,
    required this.type,
    required this.date,
    required this.reason,
    required this.status,
    this.adminResponse,
    this.senderId,
    this.doctorId,
    this.scheduleId,
    this.description,
    this.reviewedBy,
    this.createdAt,
    this.reviewedAt,
  });
  final String id, type, reason;
  final DateTime date;
  final DoctorReportStatus status;
  final String? adminResponse;
  final String? senderId, doctorId, scheduleId, description, reviewedBy;
  final DateTime? createdAt, reviewedAt;
}
