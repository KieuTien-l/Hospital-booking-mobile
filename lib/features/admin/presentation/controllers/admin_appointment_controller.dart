import 'dart:async';

import '../../../../core/state/view_state.dart';
import '../../../appointments/domain/entities/appointment.dart';
import '../../../appointments/domain/repositories/appointment_repository.dart';
import '../../../doctors/domain/entities/time_slot.dart';
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
  }) : _appointments = appointmentRepository,
       _doctors = doctorRepository,
       _schedules = workScheduleRepository,
       _slots = timeSlotRepository;

  final AppointmentRepository _appointments;
  final DoctorRepository _doctors;
  final WorkScheduleRepository _schedules;
  final TimeSlotRepository _slots;
  StreamSubscription<List<Appointment>>? _subscription;
  List<AdminAppointmentRecord> _records = const [];
  AdminAppointmentFilter _filter = const AdminAppointmentFilter();

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
    if (!force && status == ViewState.success) return;
    final request = beginRequest();
    try {
      final previousSubscription = _subscription;
      _subscription = null;
      if (previousSubscription != null) await previousSubscription.cancel();
      final stream = _appointments.watchAllAppointments().asBroadcastStream();
      final values = await stream.first;
      if (!isCurrent(request)) return;
      await _publish(values, request);
      if (!isCurrent(request)) return;
      _subscription = stream.listen(
        (updated) {
          _publish(updated, request).catchError((Object error) {
            if (isCurrent(request)) setState(ViewState.error, error);
          });
        },
        onError: (Object error) {
          if (isCurrent(request)) setState(ViewState.error, error);
        },
      );
    } catch (error) {
      if (isCurrent(request)) setState(ViewState.error, error);
    }
  }

  Future<void> refresh() => load(force: true);

  Future<void> _publish(List<Appointment> values, int request) async {
    final filtered = values.where(_matchesFilter).toList(growable: false);
    final records = await Future.wait(
      filtered.map(
        (appointment) async => AdminAppointmentRecord(
          appointment: appointment,
          hasValidRelationships: await _hasValidRelationships(appointment),
        ),
      ),
    );
    if (!isCurrent(request)) return;
    _records = List.unmodifiable(records);
    setState(records.isEmpty ? ViewState.empty : ViewState.success);
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
    final schedules = await _schedules.getWorkSchedules(
      doctorId: appointment.doctorId,
      workDate: appointment.appointmentDate,
    );
    final schedule = schedules
        .where((item) => item.id == appointment.workScheduleId)
        .firstOrNull;
    if (schedule == null || schedule.doctorId != appointment.doctorId) {
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
    return capacity != null &&
        capacity >= appointment.peopleCount &&
        booked >= appointment.peopleCount;
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
