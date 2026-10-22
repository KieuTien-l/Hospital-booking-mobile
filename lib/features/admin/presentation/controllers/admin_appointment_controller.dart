import 'dart:async';

import '../../../../core/state/view_state.dart';
import '../../../appointments/domain/entities/appointment.dart';
import '../../../appointments/domain/repositories/appointment_repository.dart';
import '../../../doctors/domain/entities/time_slot.dart';
import '../../../doctors/domain/entities/work_schedule.dart';
import '../../../doctors/domain/repositories/doctor_repository.dart';
import '../../../doctors/domain/repositories/time_slot_repository.dart';
import '../../../doctors/domain/repositories/work_schedule_repository.dart';

class AdminAppointmentFilter {
  const AdminAppointmentFilter({
    this.status,
    this.patientId,
    this.doctorId,
    this.specialtyId,
    this.date,
  });

  final AppointmentStatus? status;
  final String? patientId;
  final String? doctorId;
  final String? specialtyId;
  final DateTime? date;
}

/// An appointment plus the result of validating its persisted relationships.
class AdminAppointmentRecord {
  const AdminAppointmentRecord({
    required this.appointment,
    required this.hasValidRelationships,
  });

  final Appointment appointment;
  final bool hasValidRelationships;
}

/// Reads, filters and audits the appointment -> schedule -> slot -> doctor graph.
class AdminAppointmentController extends ViewStateController {
  AdminAppointmentController({
    required AppointmentRepository appointmentRepository,
    required DoctorRepository doctorRepository,
    required WorkScheduleRepository workScheduleRepository,
    required TimeSlotRepository timeSlotRepository,
    this.findScheduleById,
  }) : _appointments = appointmentRepository,
       _doctors = doctorRepository,
       _schedules = workScheduleRepository,
       _slots = timeSlotRepository;

  final AppointmentRepository _appointments;
  final DoctorRepository _doctors;
  final WorkScheduleRepository _schedules;
  final TimeSlotRepository _slots;
  final Future<WorkSchedule?> Function(String id)? findScheduleById;
  StreamSubscription<List<Appointment>>? _subscription;
  List<AdminAppointmentRecord> _records = const [];
  AdminAppointmentFilter _filter = const AdminAppointmentFilter();
  int _publication = 0;

  List<AdminAppointmentRecord> get records => _records;
  List<Appointment> get appointments =>
      List.unmodifiable(_records.map((record) => record.appointment));
  List<AdminAppointmentRecord> get invalidRelationshipRecords =>
      List.unmodifiable(
        _records.where((record) => !record.hasValidRelationships),
      );
  AdminAppointmentFilter get filter => _filter;

  Future<void> load({
    AdminAppointmentFilter? filter,
    bool force = false,
  }) async {
    if (filter != null) _filter = filter;
    if (!force && filter == null && status == ViewState.success) return;
    final request = beginRequest();
    _records = const [];
    try {
      final previousSubscription = _subscription;
      _subscription = null;
      if (previousSubscription != null) await previousSubscription.cancel();
      if (!isCurrent(request)) return;
      final initial = Completer<void>();
      _subscription = _appointments.watchAllAppointments().listen(
        (updated) {
          _publish(updated, request).then(
            (_) {
              if (!initial.isCompleted) initial.complete();
            },
            onError: (Object error) {
              if (isCurrent(request)) {
                _records = const [];
                setState(ViewState.error, error);
              }
              if (!initial.isCompleted) initial.complete();
            },
          );
        },
        onError: (Object error) {
          _publication++;
          if (isCurrent(request)) {
            _records = const [];
            setState(ViewState.error, error);
          }
          if (!initial.isCompleted) initial.complete();
        },
      );
      await initial.future;
    } catch (error) {
      if (isCurrent(request)) setState(ViewState.error, error);
    }
  }

  Future<void> refresh() => load(force: true);

  Future<void> _publish(List<Appointment> values, int request) async {
    final publication = ++_publication;
    final filtered = values.where(_matchesFilter).toList(growable: false);
    try {
      final records = await Future.wait(
        filtered.map(
          (appointment) async => AdminAppointmentRecord(
            appointment: appointment,
            hasValidRelationships: await _hasValidRelationships(appointment),
          ),
        ),
      );
      if (!isCurrent(request) || publication != _publication) return;
      _records = List.unmodifiable(records);
      setState(records.isEmpty ? ViewState.empty : ViewState.success);
    } catch (error) {
      if (isCurrent(request) && publication == _publication) {
        _records = const [];
        setState(ViewState.error, error);
      }
    }
  }

  bool _matchesFilter(Appointment appointment) {
    final filter = _filter;
    if (filter.status != null && appointment.status != filter.status) {
      return false;
    }
    if (!_sameText(filter.patientId, appointment.patientId) ||
        !_sameText(filter.doctorId, appointment.doctorId) ||
        !_sameText(filter.specialtyId, appointment.specialtyId)) {
      return false;
    }
    final date = filter.date;
    return date == null ||
        (appointment.appointmentDate != null &&
            _sameDate(appointment.appointmentDate!, date));
  }

  bool _sameText(String? filter, String? value) {
    final normalized = filter?.trim() ?? '';
    return normalized.isEmpty || normalized == (value?.trim() ?? '');
  }

  Future<bool> _hasValidRelationships(Appointment appointment) async {
    if (appointment.doctorId.trim().isEmpty ||
        appointment.workScheduleId.trim().isEmpty ||
        appointment.timeSlotId.trim().isEmpty ||
        appointment.appointmentDate == null) {
      return false;
    }
    final doctor = await _doctors.getDoctorById(appointment.doctorId);
    if (doctor == null) return false;
    // specialtyId is the booking-time snapshot. A doctor may have moved to
    // another specialty since then, which does not invalidate the appointment.
    final finder = findScheduleById;
    final schedule = finder != null
        ? await finder(appointment.workScheduleId)
        : (await _schedules.getWorkSchedules(
            doctorId: appointment.doctorId,
            workDate: appointment.appointmentDate,
          )).where((item) => item.id == appointment.workScheduleId).firstOrNull;
    if (schedule == null ||
        schedule.doctorId != appointment.doctorId ||
        schedule.workDate == null ||
        !_sameDate(schedule.workDate!, appointment.appointmentDate!)) {
      return false;
    }
    final slots = await _slots.getTimeSlotsByWorkSchedule(schedule.id);
    final slot = slots
        .where((item) => item.id == appointment.timeSlotId)
        .firstOrNull;
    return slot != null &&
        slot.doctorId == appointment.doctorId &&
        slot.workScheduleId == schedule.id &&
        slot.startTime == appointment.startTime &&
        slot.endTime == appointment.endTime &&
        _slotCanContainAppointment(slot, appointment);
  }

  bool _slotCanContainAppointment(TimeSlot slot, Appointment appointment) {
    final capacity = slot.capacity;
    final booked = slot.bookedCount ?? 0;
    final reservations = slot.reservationCounts;
    if (reservations.isNotEmpty &&
        (reservations.values.any((count) => count <= 0) ||
            reservations.values.fold(0, (sum, count) => sum + count) !=
                booked ||
            (appointment.status == AppointmentStatus.cancelled
                ? reservations.containsKey(appointment.id)
                : reservations[appointment.id] != appointment.peopleCount))) {
      return false;
    }
    return capacity != null &&
        capacity > 0 &&
        appointment.peopleCount > 0 &&
        booked >= 0 &&
        booked <= capacity &&
        (appointment.status == AppointmentStatus.cancelled ||
            (capacity >= appointment.peopleCount &&
                booked >= appointment.peopleCount));
  }

  bool _sameDate(DateTime left, DateTime right) =>
      left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
