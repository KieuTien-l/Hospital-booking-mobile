import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'dart:async';

import '../../../../core/state/view_state.dart';
import '../../../doctors/domain/entities/doctor.dart';
import '../../../specialties/domain/entities/specialty.dart';

import '../../domain/entities/appointment.dart';
import '../../../profile/domain/entities/patient.dart';
import '../../../doctors/domain/entities/time_slot.dart';
import '../../domain/repositories/booking_repository.dart';
import '../../domain/usecases/book_appointment.dart';

typedef AppointmentControllerStatus = ViewState;

/// Presentation state shared by profile and booking pages.
class AppointmentController extends ChangeNotifier {
  AppointmentController({
    required BookingRepository bookingRepository,
    required BookAppointment bookAppointmentUseCase,
  }) : _repository = bookingRepository,
       _bookAppointment = bookAppointmentUseCase;

  final BookingRepository _repository;
  final BookAppointment _bookAppointment;

  StreamSubscription<Patient?>? _profileSubscription;
  StreamSubscription<List<Appointment>>? _appointmentsSubscription;

  ViewState _status = ViewState.initial;
  ViewState _appointmentsStatus = ViewState.initial;
  ViewState _detailStatus = ViewState.initial;
  String? _appointmentsErrorMessage;
  String? _detailErrorMessage;
  Appointment? _appointment;
  Specialty? _selectedSpecialty;
  Doctor? _selectedDoctor;
  DateTime? _selectedDate;
  TimeSlot? _selectedTimeSlot;
  Patient? _bookingPatient;
  int _profileVersion = 0;
  int _listVersion = 0;
  int _detailVersion = 0;
  int _bookingVersion = 0;
  bool _disposed = false;
  bool _bookingInProgress = false;
  ViewState get appointmentsStatus => _appointmentsStatus;
  ViewState get detailStatus => _detailStatus;
  String? get appointmentsErrorMessage => _appointmentsErrorMessage;
  String? get detailErrorMessage => _detailErrorMessage;
  int _saveVersion = 0;
  Appointment? get appointment => _appointment;
  Specialty? get selectedSpecialty => _selectedSpecialty;
  Doctor? get selectedDoctor => _selectedDoctor;
  DateTime? get selectedDate => _selectedDate;
  TimeSlot? get selectedTimeSlot => _selectedTimeSlot;
  Patient? get bookingPatient => _bookingPatient;
  bool get isSuccess => _status == ViewState.success;
  bool get isEmpty => _status == ViewState.empty;
  bool get hasError => _status == ViewState.error;

  void selectSpecialty(Specialty? value) {
    _selectedSpecialty = value;
    _selectedDoctor = null;
    _selectedDate = null;
    _selectedTimeSlot = null;
    notifyListeners();
  }

  void selectDoctor(Doctor? value) {
    if (value != null &&
        _selectedSpecialty != null &&
        value.specialtyId != _selectedSpecialty!.id) {
      _setError(
        StateError('Doctor does not belong to the selected specialty.'),
      );
      return;
    }
    _selectedDoctor = value;
    _selectedDate = null;
    _selectedTimeSlot = null;
    notifyListeners();
  }

  void selectDate(DateTime? value) {
    _selectedDate = value == null
        ? null
        : DateTime(value.year, value.month, value.day);
    _selectedTimeSlot = null;
    notifyListeners();
  }

  void selectTimeSlot(TimeSlot? value) {
    if (value != null &&
        (!value.isAvailable ||
            _selectedDoctor == null ||
            _selectedDate == null ||
            (value.doctorId.isNotEmpty &&
                value.doctorId != _selectedDoctor!.id))) {
      _setError(StateError('Select a valid available time slot.'));
      return;
    }
    _selectedTimeSlot = value;
    notifyListeners();
  }

  void selectPatient(Patient? value) {
    _bookingPatient = value;
    notifyListeners();
  }

  void resetBooking() {
    _bookingVersion++;
    _selectedSpecialty = null;
    _selectedDoctor = null;
    _selectedDate = null;
    _selectedTimeSlot = null;
    _bookingPatient = null;
    _status = ViewState.initial;
    _errorMessage = null;
    notifyListeners();
  }

  Future<Appointment?> submitBooking({
    String? reason,
    String? note,
    String? symptoms,
    int peopleCount = 1,
  }) => book(
    patientId: _bookingPatient?.id ?? '',
    doctorId: _selectedDoctor?.id ?? '',
    workScheduleId: _selectedTimeSlot?.workScheduleId ?? '',
    timeSlotId: _selectedTimeSlot?.id ?? '',
    appointmentDate: _selectedDate,
    startTime: _selectedTimeSlot?.startTime,
    endTime: _selectedTimeSlot?.endTime,
    reason: reason,
    note: note,
    symptoms: symptoms,
    peopleCount: peopleCount,
  );

  Patient? _patient;
  List<Appointment> _appointments = const [];
  String? _errorMessage;

  AppointmentControllerStatus get status => _status;
  Patient? get patient => _patient;
  List<Appointment> get appointments => _appointments;
  List<Appointment> get pendingAppointments => _appointments
      .where((a) => a.status == AppointmentStatus.pending)
      .toList();
  List<Appointment> get confirmedAppointments => _appointments
      .where((a) => a.status == AppointmentStatus.confirmed)
      .toList();
  List<Appointment> get completedAppointments => _appointments
      .where((a) => a.status == AppointmentStatus.completed)
      .toList();
  List<Appointment> get cancelledAppointments => _appointments
      .where((a) => a.status == AppointmentStatus.cancelled)
      .toList();
  List<Appointment> get upcomingAppointments => _appointments
      .where(
        (a) =>
            a.status == AppointmentStatus.pending ||
            a.status == AppointmentStatus.confirmed,
      )
      .toList();
  List<Appointment> get pastAppointments => _appointments
      .where(
        (a) =>
            a.status == AppointmentStatus.completed ||
            a.status == AppointmentStatus.cancelled ||
            a.status == AppointmentStatus.noShow,
      )
      .toList();
  String? get errorMessage => _errorMessage;
  bool get isLoading => _status == AppointmentControllerStatus.loading;

  void watchProfile(String authUserId) {
    final version = ++_profileVersion;
    _listVersion++;
    _profileSubscription?.cancel();
    _appointmentsSubscription?.cancel();
    _appointmentsStatus = ViewState.initial;
    _appointmentsErrorMessage = null;
    _patient = null;
    _appointments = const [];
    _errorMessage = null;
    _status = AppointmentControllerStatus.loading;
    notifyListeners();

    try {
      _profileSubscription = _repository
          .watchPatientByAuthUser(authUserId)
          .listen(
            (profile) {
              if (_disposed || version != _profileVersion) return;
              _patient = profile;
              _status = profile == null ? ViewState.empty : ViewState.success;
              _errorMessage = null;
              _watchAppointments(profile?.id);
              notifyListeners();
            },
            onError: (Object error) {
              if (!_disposed && version == _profileVersion) _setError(error);
            },
          );
    } catch (error) {
      _setError(error);
    }
  }

  Future<Patient?> saveProfile(Patient patient) async {
    final version = ++_saveVersion;
    final profileVersion = _profileVersion;
    _status = AppointmentControllerStatus.loading;
    _errorMessage = null;
    notifyListeners();
    try {
      final savedPatient = await _repository.savePatient(patient);
      if (_disposed ||
          version != _saveVersion ||
          profileVersion != _profileVersion) {
        return null;
      }
      _patient = savedPatient;
      _status = ViewState.success;
      return savedPatient;
    } catch (error) {
      if (version == _saveVersion && profileVersion == _profileVersion) {
        _setError(error);
      }
      return null;
    } finally {
      if (_status != AppointmentControllerStatus.error) {
        notifyListeners();
      }
    }
  }

  Future<Appointment?> book({
    required String patientId,
    required String doctorId,
    required String workScheduleId,
    required String timeSlotId,
    DateTime? appointmentDate,
    String? startTime,
    String? endTime,
    String? reason,
    String? note,
    String? symptoms,
    int peopleCount = 1,
  }) async {
    if (_bookingInProgress) return null;
    _bookingInProgress = true;
    final version = _bookingVersion;
    _status = AppointmentControllerStatus.loading;
    _errorMessage = null;
    notifyListeners();
    try {
      final appointment = await _bookAppointment(
        patientId: patientId,
        doctorId: doctorId,
        workScheduleId: workScheduleId,
        timeSlotId: timeSlotId,
        appointmentDate: appointmentDate,
        startTime: startTime,
        endTime: endTime,
        reason: reason,
        note: note,
        symptoms: symptoms,
        peopleCount: peopleCount,
      );
      if (_disposed || version != _bookingVersion) return null;
      resetBooking();
      _appointment = appointment;
      _status = ViewState.success;
      return appointment;
    } catch (error) {
      if (!_disposed && version == _bookingVersion) _setError(error);
      return null;
    } finally {
      _bookingInProgress = false;
      if (_status != AppointmentControllerStatus.error) {
        notifyListeners();
      }
    }
  }

  Future<Appointment?> cancelAppointment(
    String appointmentId,
    String cancellationReason,
  ) async {
    _status = AppointmentControllerStatus.loading;
    _errorMessage = null;
    notifyListeners();
    try {
      final updatedAppointment = await _repository.cancelAppointment(
        appointmentId,
        cancellationReason,
      );
      _appointment = updatedAppointment;
      _status = ViewState.success;
      return updatedAppointment;
    } catch (error) {
      _setError(error);
      return null;
    } finally {
      if (_status != AppointmentControllerStatus.error) {
        notifyListeners();
      }
    }
  }

  Future<Appointment?> rescheduleAppointment({
    required String appointmentId,
    required String newWorkScheduleId,
    required String newTimeSlotId,
    required DateTime newDate,
    required String newStartTime,
    required String newEndTime,
  }) async {
    _status = AppointmentControllerStatus.loading;
    _errorMessage = null;
    notifyListeners();
    try {
      final updatedAppointment = await _repository.rescheduleAppointment(
        appointmentId,
        newWorkScheduleId,
        newTimeSlotId,
        newDate,
        newStartTime,
        newEndTime,
      );
      _appointment = updatedAppointment;
      _status = ViewState.success;
      return updatedAppointment;
    } catch (error) {
      _setError(error);
      return null;
    } finally {
      if (_status != AppointmentControllerStatus.error) {
        notifyListeners();
      }
    }
  }

  /// Returns the slots belonging to [doctorId] on the selected calendar day.
  Future<List<TimeSlot>> getAvailableSlotsForDoctorAndDate({
    required String doctorId,
    required DateTime workDate,
  }) async {
    _status = ViewState.loading;
    _errorMessage = null;
    notifyListeners();
    try {
      final values = await _repository.getAvailableTimeSlotsByDoctorAndDate(
        doctorId: doctorId,
        workDate: workDate,
      );
      if (_disposed) return const [];
      _status = values.isEmpty ? ViewState.empty : ViewState.success;
      notifyListeners();
      return List.unmodifiable(values);
    } catch (error) {
      _setError(error);
      return const [];
    }
  }

  Future<Appointment?> getAppointmentDetails(String appointmentId) async {
    final version = ++_detailVersion;
    _appointment = null;
    _detailStatus = ViewState.loading;
    _detailErrorMessage = null;
    notifyListeners();
    try {
      final value = await _repository.getAppointmentById(appointmentId);
      if (_disposed || version != _detailVersion) return null;
      _appointment = value;
      _detailStatus = ViewState.success;
      notifyListeners();
      return value;
    } catch (error) {
      if (!_disposed && version == _detailVersion) {
        _detailStatus = ViewState.error;
        _detailErrorMessage = error.toString();
        notifyListeners();
      }
      return null;
    }
  }

  Future<Appointment?> loadAppointmentDetail(String id) =>
      getAppointmentDetails(id);
  void loadAppointments(String patientId) => _watchAppointments(patientId);

  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    _status = AppointmentControllerStatus.idle;
    notifyListeners();
  }

  void _watchAppointments(String? patientId) {
    final version = ++_listVersion;
    _appointmentsSubscription?.cancel();
    _appointments = const [];
    _appointmentsErrorMessage = null;
    if (patientId == null || patientId.isEmpty) {
      _appointmentsStatus = ViewState.empty;
      notifyListeners();
      return;
    }
    _appointmentsStatus = ViewState.loading;
    notifyListeners();
    void fail(Object error) {
      if (_disposed || version != _listVersion) return;
      _appointmentsStatus = ViewState.error;
      _appointmentsErrorMessage = error.toString();
      notifyListeners();
    }

    try {
      _appointmentsSubscription = _repository
          .watchAppointmentsByPatient(patientId)
          .listen((values) {
            if (_disposed || version != _listVersion) return;
            _appointments = List.unmodifiable(values);
            _appointmentsStatus = values.isEmpty
                ? ViewState.empty
                : ViewState.success;
            _appointmentsErrorMessage = null;
            notifyListeners();
          }, onError: fail);
    } catch (error) {
      fail(error);
    }
  }

  void _setError(Object error) {
    if (_disposed) return;
    _status = AppointmentControllerStatus.error;
    _errorMessage = _messageFor(error);
    notifyListeners();
  }

  String _messageFor(Object error) {
    if (error is FirebaseException && error.code == 'resource-exhausted') {
      return 'Firebase đang tạm giới hạn lượng truy cập. '
          'Lịch hẹn chưa được tạo; vui lòng chờ vài phút rồi thử lại một lần.';
    }

    final rawMessage = error.toString();
    if (rawMessage.contains('cloud_firestore/resource-exhausted') ||
        rawMessage.contains('RESOURCE_EXHAUSTED')) {
      return 'Firebase đang tạm giới hạn lượng truy cập. '
          'Lịch hẹn chưa được tạo; vui lòng chờ vài phút rồi thử lại một lần.';
    }
    return rawMessage.replaceFirst('Exception: ', '');
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _profileSubscription?.cancel();
    _appointmentsSubscription?.cancel();
    super.dispose();
  }
}
