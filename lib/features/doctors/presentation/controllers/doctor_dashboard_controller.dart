import 'dart:async';

import '../../../../core/state/view_state.dart';
import '../../../appointments/domain/entities/appointment.dart';
import '../../../appointments/domain/repositories/appointment_repository.dart';
import '../../domain/entities/doctor.dart';
import '../../domain/entities/work_schedule.dart';
import '../../domain/repositories/doctor_repository.dart';
import '../../domain/repositories/work_schedule_repository.dart';

/// Live data for the Doctor Dashboard.
///
/// A dashboard starts with the authenticated account id, resolves its
/// `BAC_SI` profile, then reads only schedules and appointments belonging to
/// that doctor. The UI remains responsible for presentation only.
class DoctorDashboardController extends ViewStateController {
  DoctorDashboardController({
    required DoctorRepository doctorRepository,
    required WorkScheduleRepository workScheduleRepository,
    required AppointmentRepository appointmentRepository,
  }) : _doctors = doctorRepository,
       _schedules = workScheduleRepository,
       _appointments = appointmentRepository;

  final DoctorRepository _doctors;
  final WorkScheduleRepository _schedules;
  final AppointmentRepository _appointments;

  StreamSubscription<List<Appointment>>? _appointmentSubscription;
  Doctor? _doctor;
  List<WorkSchedule> _workSchedules = const [];
  List<Appointment> _doctorAppointments = const [];
  String _authUserId = '';
  DateTime? _selectedDate;
  String? _appointmentError;
  bool _disposed = false;

  Doctor? get doctor => _doctor;
  List<WorkSchedule> get workSchedules => _workSchedules;
  List<Appointment> get appointments => _doctorAppointments;
  String? get appointmentError => _appointmentError;
  DateTime? get selectedDate => _selectedDate;

  bool matches({required String authUserId, required DateTime date}) {
    return _authUserId == authUserId.trim() &&
        _isSameDate(_selectedDate, date);
  }

  List<Appointment> get appointmentsForSelectedDate {
    final selectedDate = _selectedDate;
    if (selectedDate == null) return const [];

    return _doctorAppointments
        .where(
          (appointment) =>
              _isSameDate(appointment.appointmentDate, selectedDate),
        )
        .toList(growable: false);
  }

  /// Number of places with an active appointment for the selected date.
  int get bookedCount => _sumPeople(
    appointmentsForSelectedDate.where(
      (appointment) => appointment.status != AppointmentStatus.cancelled,
    ),
  );

  int get completedCount => _sumPeople(
    appointmentsForSelectedDate.where(
      (appointment) => appointment.status == AppointmentStatus.completed,
    ),
  );

  int get waitingCount => _sumPeople(
    appointmentsForSelectedDate.where(
      (appointment) =>
          appointment.status == AppointmentStatus.pending ||
          appointment.status == AppointmentStatus.confirmed,
    ),
  );

  Future<void> load({
    required String authUserId,
    required DateTime selectedDate,
  }) async {
    final normalizedUserId = authUserId.trim();
    final normalizedDate = _dateOnly(selectedDate);
    if (matches(authUserId: normalizedUserId, date: normalizedDate) &&
        status != ViewState.error) {
      return;
    }

    _authUserId = normalizedUserId;
    _selectedDate = normalizedDate;
    _workSchedules = const [];
    _appointmentError = null;
    final request = beginRequest();

    if (normalizedUserId.isEmpty) {
      _doctor = null;
      _doctorAppointments = const [];
      await _appointmentSubscription?.cancel();
      _appointmentSubscription = null;
      if (isCurrent(request)) setState(ViewState.empty);
      return;
    }

    try {
      final doctor = await _doctors.getDoctorByUserId(normalizedUserId);
      if (!isCurrent(request)) return;
      if (doctor == null) {
        _doctor = null;
        _doctorAppointments = const [];
        await _appointmentSubscription?.cancel();
        _appointmentSubscription = null;
        setState(ViewState.empty);
        return;
      }

      final schedules = await _schedules.getWorkSchedules(
        doctorId: doctor.id,
        workDate: normalizedDate,
      );
      if (!isCurrent(request)) return;

      final doctorChanged = _doctor?.id != doctor.id;
      _doctor = doctor;
      _workSchedules = List.unmodifiable(schedules);
      if (doctorChanged || _appointmentSubscription == null) {
        await _appointmentSubscription?.cancel();
        _appointmentSubscription = _appointments
            .watchAppointmentsByDoctor(doctor.id)
            .listen(
              (appointments) {
                if (_disposed || _doctor?.id != doctor.id) return;
                _doctorAppointments = List.unmodifiable(appointments);
                _appointmentError = null;
                notifyListeners();
              },
              onError: (Object error) {
                if (_disposed || _doctor?.id != doctor.id) return;
                _appointmentError = error.toString();
                notifyListeners();
              },
            );
      }
      setState(schedules.isEmpty ? ViewState.empty : ViewState.success);
    } catch (error) {
      if (isCurrent(request)) setState(ViewState.error, error);
    }
  }

  int _sumPeople(Iterable<Appointment> values) => values.fold(
    0,
    (total, appointment) => total + appointment.peopleCount,
  );

  DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

  bool _isSameDate(DateTime? left, DateTime right) =>
      left != null &&
      left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;

  @override
  void dispose() {
    _disposed = true;
    _appointmentSubscription?.cancel();
    super.dispose();
  }
}
