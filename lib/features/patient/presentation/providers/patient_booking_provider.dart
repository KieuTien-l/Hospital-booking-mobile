import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/models/appointment_model.dart';
import '../../../../core/models/patient_model.dart';
import '../../../../core/models/time_slot_model.dart';
import '../../domain/repositories/patient_booking_repository.dart';
import '../../domain/usecases/book_appointment.dart';

enum PatientBookingStatus { idle, loading, error }

/// Presentation state shared by profile and booking pages.
class PatientBookingProvider extends ChangeNotifier {
  PatientBookingProvider({
    required PatientBookingRepository patientBookingRepository,
    required BookAppointment bookAppointmentUseCase,
  }) : _repository = patientBookingRepository,
       _bookAppointment = bookAppointmentUseCase;

  final PatientBookingRepository _repository;
  final BookAppointment _bookAppointment;

  StreamSubscription<Patient?>? _profileSubscription;
  StreamSubscription<List<Appointment>>? _appointmentsSubscription;

  PatientBookingStatus _status = PatientBookingStatus.idle;
  Patient? _patient;
  List<Appointment> _appointments = const [];
  String? _errorMessage;

  PatientBookingStatus get status => _status;
  Patient? get patient => _patient;
  List<Appointment> get appointments => _appointments;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _status == PatientBookingStatus.loading;

  void watchProfile(String authUserId) {
    _profileSubscription?.cancel();
    _appointmentsSubscription?.cancel();
    _patient = null;
    _appointments = const [];
    _errorMessage = null;
    _status = PatientBookingStatus.loading;
    notifyListeners();

    _profileSubscription = _repository
        .watchPatientByAuthUser(authUserId)
        .listen((profile) {
          _patient = profile;
          _status = PatientBookingStatus.idle;
          _errorMessage = null;
          _watchAppointments(profile?.id);
          notifyListeners();
        }, onError: _setError);
  }

  Future<Patient> saveProfile(Patient patient) async {
    _status = PatientBookingStatus.loading;
    _errorMessage = null;
    notifyListeners();
    try {
      final savedPatient = await _repository.savePatient(patient);
      _patient = savedPatient;
      _status = PatientBookingStatus.idle;
      return savedPatient;
    } catch (error) {
      _setError(error);
      rethrow;
    } finally {
      if (_status != PatientBookingStatus.error) {
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
    _status = PatientBookingStatus.loading;
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
      _status = PatientBookingStatus.idle;
      return appointment;
    } catch (error) {
      _setError(error);
      rethrow;
    } finally {
      if (_status != PatientBookingStatus.error) {
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
    _status = PatientBookingStatus.loading;
    _errorMessage = null;
    notifyListeners();
    try {
      final appointment = await _repository.getAppointmentById(appointmentId);
      _status = PatientBookingStatus.idle;
      return appointment;
    } catch (error) {
      _setError(error);
      rethrow;
    } finally {
      if (_status != PatientBookingStatus.error) {
        notifyListeners();
      }
    }
  }

  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    _status = PatientBookingStatus.idle;
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
    _status = PatientBookingStatus.error;
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
