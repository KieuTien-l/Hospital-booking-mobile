import 'dart:async';

import '../../../../core/state/view_state.dart';
import '../../domain/entities/patient.dart';
import '../../domain/repositories/patient_repository.dart';

class PatientProfileController extends ViewStateController {
  PatientProfileController(this._repository);
  final PatientRepository _repository;
  Patient? _patient;
  List<Patient> _patients = const [];
  String? _patientId;
  String? _authUserId;
  StreamSubscription<List<Patient>>? _subscription;
  Patient? get patient => _patient;
  List<Patient> get patients => _patients;
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
      _patients = value == null ? const [] : [value];
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
        .watchPatientsByOwner(authUserId)
        .listen(
          (values) {
            if (!isCurrent(token)) return;
            _patients = List.unmodifiable(values);
            final selectedId = _patient?.id;
            _patient = selectedId == null
                ? (values.isEmpty ? null : values.first)
                : values.where((item) => item.id == selectedId).firstOrNull ??
                      (values.isEmpty ? null : values.first);
            setState(values.isEmpty ? ViewState.empty : ViewState.success);
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
      final index = _patients.indexWhere((item) => item.id == saved.id);
      _patients = index < 0
          ? List.unmodifiable([..._patients, saved])
          : List.unmodifiable([
              for (var i = 0; i < _patients.length; i++)
                if (i == index) saved else _patients[i],
            ]);
      _patientId = saved.id;
      setState(ViewState.success);
      if (_authUserId != null) _subscribe(_authUserId!, token);
      return saved;
    } catch (error) {
      if (isCurrent(token)) setState(ViewState.error, error);
      return null;
    }
  }

  void selectPatient(Patient patient) {
    if (_patients.any((item) => item.id == patient.id)) {
      _patient = patient;
      notifyListeners();
    }
  }

  String? validateProfile(Patient patient) {
    final fullName = patient.fullName.trim();
    if (fullName.length < 2 ||
        fullName.length > 120 ||
        RegExp(r'^\d+$').hasMatch(fullName)) {
      return 'Họ tên phải có từ 2 đến 120 ký tự và không chỉ gồm chữ số';
    }
    if (!RegExp(r'^0\d{9,10}$').hasMatch(patient.phone.trim())) {
      return 'Số điện thoại phải gồm 10 hoặc 11 chữ số và bắt đầu bằng 0';
    }
    final email = patient.email.trim();
    if (email.isNotEmpty &&
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      return 'Email không hợp lệ';
    }
    final nationalId = patient.nationalId?.trim() ?? '';
    if (nationalId.isNotEmpty && !RegExp(r'^\d{12}$').hasMatch(nationalId)) {
      return 'CCCD phải gồm đúng 12 chữ số';
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
