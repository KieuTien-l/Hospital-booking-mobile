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
    if (!force && status == ViewState.success) return;
    final request = beginRequest();
    try {
      final previousSpecialties = _specialtySubscription;
      final previousAppointments = _appointmentSubscription;
      _specialtySubscription = null;
      _appointmentSubscription = null;
      if (previousSpecialties != null) await previousSpecialties.cancel();
      if (previousAppointments != null) {
        await previousAppointments.cancel();
      }
      // Reuse each source for its initial value and its subsequent live
      // updates. `asBroadcastStream` also supports simple single-listener
      // repository implementations used outside Firestore.
      final specialtyStream = _specialties
          .watchAllSpecialties()
          .asBroadcastStream();
      final appointmentStream = _appointments
          .watchAllAppointments()
          .asBroadcastStream();
      final values = await Future.wait<Object>([
        specialtyStream.first,
        _doctors.getAllDoctors(),
        appointmentStream.first,
      ], eagerError: true);
      if (!isCurrent(request)) return;
      _specialtyValues = List.unmodifiable(values[0] as List<Specialty>);
      _doctorValues = List.unmodifiable(values[1] as List<Doctor>);
      _appointmentValues = List.unmodifiable(values[2] as List<Appointment>);
      _listenToLiveValues(specialtyStream, appointmentStream);
      final isEmpty =
          specialtyCount == 0 &&
          activeDoctorCount == 0 &&
          appointmentCount == 0;
      setState(isEmpty ? ViewState.empty : ViewState.success);
    } catch (error) {
      if (isCurrent(request)) setState(ViewState.error, error);
    }
  }

  Future<void> refresh() => load(force: true);

  void _listenToLiveValues(
    Stream<List<Specialty>> specialtyStream,
    Stream<List<Appointment>> appointmentStream,
  ) {
    _specialtySubscription = specialtyStream.listen((values) {
      _specialtyValues = List.unmodifiable(values);
      _publishLiveState();
    }, onError: (Object error) => setState(ViewState.error, error));
    _appointmentSubscription = appointmentStream.listen((values) {
      _appointmentValues = List.unmodifiable(values);
      _publishLiveState();
    }, onError: (Object error) => setState(ViewState.error, error));
  }

  void _publishLiveState() {
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
