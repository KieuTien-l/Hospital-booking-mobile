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
  });
  final String id, type, reason;
  final DateTime date;
  final DoctorReportStatus status;
  final String? adminResponse;
}

class DoctorHealthRecordDraft {
  const DoctorHealthRecordDraft({
    required this.requestId,
    required this.appointmentId,
    required this.diagnosis,
    required this.recordType,
    this.id,
    this.notes = '',
    this.prescription = '',
  });
  final String requestId, appointmentId, diagnosis, recordType;
  final String? id, notes, prescription;
}

class DoctorTestResultDraft {
  const DoctorTestResultDraft({
    required this.requestId,
    required this.appointmentId,
    required this.testName,
    required this.resultDescription,
    this.id,
    this.resultType = 'Khác',
    this.conclusion = '',
    this.referenceRange = '',
  });
  final String requestId, appointmentId, testName, resultDescription;
  final String? id, resultType, conclusion, referenceRange;
}

class DoctorClinicalSaveResult {
  const DoctorClinicalSaveResult({required this.id, required this.message});
  final String id, message;
}

class DoctorAppointmentCompletion {
  const DoctorAppointmentCompletion({
    required this.id,
    required this.status,
    required this.message,
  });

  final String id;
  final String status;
  final String message;
}

class DoctorHealthRecordSummary {
  const DoctorHealthRecordSummary({
    required this.id,
    required this.diagnosis,
    required this.notes,
    required this.prescription,
    required this.recordType,
  });
  final String id, diagnosis, notes, prescription, recordType;
}

class DoctorTestResultSummary {
  const DoctorTestResultSummary({
    required this.id,
    required this.testName,
    required this.resultDescription,
    required this.resultType,
    required this.conclusion,
    required this.referenceRange,
  });
  final String id,
      testName,
      resultDescription,
      resultType,
      conclusion,
      referenceRange;
}

/// Read-only history returned only after the Worker verifies that this doctor
/// has a valid confirmed/completed appointment with the patient.
class DoctorPatientHistory {
  const DoctorPatientHistory({
    required this.patientId,
    required this.visits,
    required this.healthRecords,
    required this.testResults,
  });

  final String patientId;
  final List<DoctorPatientVisit> visits;
  final List<DoctorHealthRecordSummary> healthRecords;
  final List<DoctorTestResultSummary> testResults;
}

class DoctorPatientVisit {
  const DoctorPatientVisit({
    required this.id,
    required this.date,
    required this.status,
  });

  final String id;
  final DateTime date;
  final String status;
}
