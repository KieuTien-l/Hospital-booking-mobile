import 'dart:async';

import '../../../../core/state/view_state.dart';
import '../../../appointments/domain/entities/appointment.dart';
import '../../../appointments/domain/repositories/appointment_repository.dart';
import '../../../doctors/domain/entities/doctor.dart';
import '../../../doctors/domain/repositories/doctor_repository.dart';
import '../../../specialties/domain/entities/specialty.dart';
import '../../../specialties/domain/repositories/specialty_repository.dart';

/// Live, backend-facing data source for the administrator dashboard.
class AdminDashboardController extends ViewStateController {
  AdminDashboardController({
    required SpecialtyRepository specialtyRepository,
    required DoctorRepository doctorRepository,
    required AppointmentRepository appointmentRepository,
  }) : _specialties = specialtyRepository,
       _doctors = doctorRepository,
       _appointments = appointmentRepository;

  final SpecialtyRepository _specialties;
  final DoctorRepository _doctors;
  final AppointmentRepository _appointments;
  StreamSubscription<List<Specialty>>? _specialtySubscription;
  StreamSubscription<List<Appointment>>? _appointmentSubscription;
  List<Specialty> _specialtyValues = const [];
  List<Doctor> _doctorValues = const [];
  List<Appointment> _appointmentValues = const [];
  final Set<String> _sourceErrors = {};
  bool _ready = false;

  List<Specialty> get specialties => _specialtyValues;
  List<Doctor> get doctors => _doctorValues;
  List<Appointment> get appointments => _appointmentValues;
  int get specialtyCount => specialties.length;
  int get activeDoctorCount =>
      doctors.where((doctor) => doctor.isActive).length;
  int get appointmentCount => appointments.length;
  int get pendingAppointmentCount => appointments
      .where((item) => item.status == AppointmentStatus.pending)
      .length;

  Future<void> load({bool force = false}) async {
    if (!force && (status == ViewState.success || status == ViewState.empty)) {
      return;
    }
    final request = beginRequest();
    _ready = false;
    _sourceErrors.clear();
    _specialtyValues = const [];
    _doctorValues = const [];
    _appointmentValues = const [];
    try {
      final previousSpecialties = _specialtySubscription;
      final previousAppointments = _appointmentSubscription;
      _specialtySubscription = null;
      _appointmentSubscription = null;
      if (previousSpecialties != null) await previousSpecialties.cancel();
      if (previousAppointments != null) {
        await previousAppointments.cancel();
      }
      if (!isCurrent(request)) return;
      final specialtiesReady = Completer<void>();
      final appointmentsReady = Completer<void>();
      void failed(String source, Object error, Completer<void> initial) {
        if (!isCurrent(request)) return;
        _sourceErrors.add(source);
        _ready = false;
        _specialtyValues = const [];
        _appointmentValues = const [];
        _doctorValues = const [];
        setState(ViewState.error, error);
        if (!initial.isCompleted) initial.completeError(error);
      }

      _specialtySubscription = _specialties.watchAllSpecialties().listen(
        (values) {
          if (!isCurrent(request) || _sourceErrors.isNotEmpty) return;
          _specialtyValues = List.unmodifiable(values);
          _sourceErrors.remove('specialties');
          if (!specialtiesReady.isCompleted) specialtiesReady.complete();
          _publishLiveState();
        },
        onError: (Object error) =>
            failed('specialties', error, specialtiesReady),
      );
      _appointmentSubscription = _appointments.watchAllAppointments().listen(
        (values) {
          if (!isCurrent(request) || _sourceErrors.isNotEmpty) return;
          _appointmentValues = List.unmodifiable(values);
          _sourceErrors.remove('appointments');
          if (!appointmentsReady.isCompleted) appointmentsReady.complete();
          _publishLiveState();
        },
        onError: (Object error) =>
            failed('appointments', error, appointmentsReady),
      );
      List<Doctor> doctors = const [];
      await Future.wait([
        specialtiesReady.future,
        appointmentsReady.future,
        _doctors.getAllDoctors().then((values) {
          doctors = values;
        }),
      ], eagerError: true);
      if (!isCurrent(request)) return;
      _doctorValues = List.unmodifiable(doctors);
      _ready = true;
      _publishLiveState();
    } catch (error) {
      if (isCurrent(request)) {
        _ready = false;
        _specialtyValues = const [];
        _doctorValues = const [];
        _appointmentValues = const [];
        setState(ViewState.error, error);
      }
    }
  }

  Future<void> refresh() => load(force: true);

  void _publishLiveState() {
    if (!_ready || _sourceErrors.isNotEmpty) return;
    final isEmpty =
        specialtyCount == 0 && activeDoctorCount == 0 && appointmentCount == 0;
    setState(isEmpty ? ViewState.empty : ViewState.success);
  }

  @override
  void dispose() {
    _specialtySubscription?.cancel();
    _appointmentSubscription?.cancel();
    super.dispose();
  }
}
