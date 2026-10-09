import 'dart:async';

import '../../../../core/state/view_state.dart';
import '../../domain/entities/patient.dart';
import '../../domain/repositories/patient_repository.dart';

class PatientProfileController extends ViewStateController {
  PatientProfileController(this._repository);
  final PatientRepository _repository;
  Patient? _patient;
  String? _patientId;
  String? _authUserId;
  StreamSubscription<Patient?>? _subscription;
  Patient? get patient => _patient;
  Future<void> loadPatient(String patientId) async {
    _patientId = patientId;
    _authUserId = null;
    _patient = null;
    final token = beginRequest();
    try {
      await _subscription?.cancel();
      if (!isCurrent(token)) return;
      final value = await _repository.getPatientById(patientId);
      if (!isCurrent(token)) return;
      _patient = value;
      setState(value == null ? ViewState.empty : ViewState.success);
    } catch (error) {
      if (isCurrent(token)) setState(ViewState.error, error);
    }
  }

  Future<void> watchPatient(String authUserId) async {
    _authUserId = authUserId;
    _patientId = null;
    _patient = null;
    final token = beginRequest();
    try {
      await _subscription?.cancel();
      if (!isCurrent(token)) return;
      _subscribe(authUserId, token);
    } catch (error) {
      if (isCurrent(token)) setState(ViewState.error, error);
    }
  }

  void _subscribe(String authUserId, int token) {
    _subscription = _repository
        .watchPatientByAuthUser(authUserId)
        .listen(
          (value) {
            if (!isCurrent(token)) return;
            _patient = value;
            setState(value == null ? ViewState.empty : ViewState.success);
          },
          onError: (Object error) {
            if (isCurrent(token)) setState(ViewState.error, error);
          },
        );
  }

  Future<void> refreshPatient() async {
    if (_authUserId != null) {
      await watchPatient(_authUserId!);
    } else if (_patientId != null) {
      await loadPatient(_patientId!);
    }
  }

  Future<Patient?> updatePatient(Patient patient) async {
    final token = beginRequest();
    try {
      await _subscription?.cancel();
      if (!isCurrent(token)) return null;
      // First-time users do not have a BENH_NHAN document yet.  Treat an
      // empty id as a create so the profile form can be used to complete the
      // booking prerequisite instead of failing an update request.
      final saved = patient.id.trim().isEmpty
          ? await _repository.createPatient(patient)
          : await _repository.updatePatient(patient);
      if (!isCurrent(token)) return null;
      _patient = saved;
      _patientId = saved.id;
      setState(ViewState.success);
      if (_authUserId != null) _subscribe(_authUserId!, token);
      return saved;
    } catch (error) {
      if (isCurrent(token)) setState(ViewState.error, error);
      return null;
    }
  }

  String? validateProfile(Patient patient) {
    if (patient.fullName.trim().isEmpty) {
      return 'Họ tên không được để trống';
    }
    if (patient.phone.trim().isEmpty) {
      return 'Số điện thoại không được để trống';
    }
    if (patient.dateOfBirth == null) {
      return 'Ngày sinh không được để trống';
    }
    if (patient.gender?.trim().isEmpty ?? true) {
      return 'Giới tính không được để trống';
    }
    return null; // Return null if valid
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
