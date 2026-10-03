import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/entities/appointment.dart';
import '../../../profile/domain/entities/patient.dart';
import '../../../doctors/domain/entities/time_slot.dart';
import '../../domain/repositories/booking_repository.dart';
import '../../domain/usecases/book_appointment.dart';

enum AppointmentControllerStatus { idle, loading, error }

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

  AppointmentControllerStatus _status = AppointmentControllerStatus.idle;
  Patient? _patient;
  List<Appointment> _appointments = const [];
  String? _errorMessage;

  AppointmentControllerStatus get status => _status;
  Patient? get patient => _patient;
  List<Appointment> get appointments => _appointments;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _status == AppointmentControllerStatus.loading;

  void watchProfile(String authUserId) {
    _profileSubscription?.cancel();
    _appointmentsSubscription?.cancel();
    _patient = null;
    _appointments = const [];
    _errorMessage = null;
    _status = AppointmentControllerStatus.loading;
    notifyListeners();

    _profileSubscription = _repository
        .watchPatientByAuthUser(authUserId)
        .listen((profile) {
          _patient = profile;
          _status = AppointmentControllerStatus.idle;
          _errorMessage = null;
          _watchAppointments(profile?.id);
          notifyListeners();
        }, onError: _setError);
  }

  Future<Patient> saveProfile(Patient patient) async {
    _status = AppointmentControllerStatus.loading;
    _errorMessage = null;
    notifyListeners();
    try {
      final savedPatient = await _repository.savePatient(patient);
      _patient = savedPatient;
      _status = AppointmentControllerStatus.idle;
      return savedPatient;
    } catch (error) {
      _setError(error);
      rethrow;
    } finally {
      if (_status != AppointmentControllerStatus.error) {
        notifyListeners();
      }
    }
  }

  Future<Appointment> book({
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
      _status = AppointmentControllerStatus.idle;
      return appointment;
    } catch (error) {
      _setError(error);
      rethrow;
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
  }) {
    return _repository.getAvailableTimeSlotsByDoctorAndDate(
      doctorId: doctorId,
      workDate: workDate,
    );
  }

  /// Loads the full record for an appointment selected from the history list.
  Future<Appointment> getAppointmentDetails(String appointmentId) async {
    _status = AppointmentControllerStatus.loading;
    _errorMessage = null;
    notifyListeners();
    try {
      final appointment = await _repository.getAppointmentById(appointmentId);
      _status = AppointmentControllerStatus.idle;
      return appointment;
    } catch (error) {
      _setError(error);
      rethrow;
    } finally {
      if (_status != AppointmentControllerStatus.error) {
        notifyListeners();
      }
    }
  }

  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    _status = AppointmentControllerStatus.idle;
    notifyListeners();
  }

  void _watchAppointments(String? patientId) {
    _appointmentsSubscription?.cancel();
    if (patientId == null || patientId.isEmpty) return;
    _appointmentsSubscription = _repository
        .watchAppointmentsByPatient(patientId)
        .listen((appointments) {
          _appointments = appointments;
          notifyListeners();
        }, onError: _setError);
  }

  void _setError(Object error) {
    _status = AppointmentControllerStatus.error;
    _errorMessage = error.toString().replaceFirst('Exception: ', '');
    notifyListeners();
  }

  @override
  void dispose() {
    _profileSubscription?.cancel();
    _appointmentsSubscription?.cancel();
    super.dispose();
  }
}
