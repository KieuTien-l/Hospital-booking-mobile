import '../../../../core/state/view_state.dart';
import '../../../doctors/domain/entities/doctor.dart';
import '../../../doctors/domain/entities/time_slot.dart';
import '../../../doctors/domain/entities/work_schedule.dart';
import '../../../specialties/domain/entities/specialty.dart';
import '../../domain/repositories/admin_management_repository.dart';

/// Coordinates administrator writes and exposes loading/error state to a UI.
class AdminManagementController extends ViewStateController {
  AdminManagementController(this._repository);

  final AdminManagementRepository _repository;
  String? _lastOperation;

  String? get lastOperation => _lastOperation;

  Future<Specialty?> saveSpecialty(Specialty specialty) =>
      _save('specialty', () => _repository.saveSpecialty(specialty));

  Future<Doctor?> saveDoctor(Doctor doctor) =>
      _save('doctor', () => _repository.saveDoctor(doctor));

  Future<WorkSchedule?> saveWorkSchedule(WorkSchedule schedule) =>
      _save('schedule', () => _repository.saveWorkSchedule(schedule));

  Future<TimeSlot?> saveTimeSlot(TimeSlot slot) =>
      _save('time slot', () => _repository.saveTimeSlot(slot));

  Future<Doctor?> transferDoctorToSpecialty({
    required String doctorId,
    required String targetSpecialtyId,
  }) => _save(
    'doctor transfer',
    () => _repository.transferDoctorToSpecialty(
      doctorId: doctorId,
      targetSpecialtyId: targetSpecialtyId,
    ),
  );

  Future<T?> _save<T>(String operation, Future<T> Function() action) async {
    final request = beginRequest();
    try {
      final result = await action();
      if (isCurrent(request)) {
        _lastOperation = operation;
        setState(ViewState.success);
      }
      return result;
    } catch (error) {
      if (isCurrent(request)) setState(ViewState.error, error);
      return null;
    }
  }
}
