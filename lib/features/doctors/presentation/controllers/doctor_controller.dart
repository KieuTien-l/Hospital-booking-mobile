import '../../../../core/state/view_state.dart';
import '../../domain/entities/doctor.dart';
import '../../domain/repositories/doctor_repository.dart';

class DoctorController extends ViewStateController {
  DoctorController(this._repository);
  final DoctorRepository _repository;
  List<Doctor> _doctors = const [];
  String? _selectedSpecialtyId;
  List<Doctor> get doctors => _doctors;
  String? get selectedSpecialtyId => _selectedSpecialtyId;
  Future<void> selectSpecialty(String? id) => _load(id);
  Future<void> loadDoctors() => _load(null);
  Future<void> loadDoctorsBySpecialty(String id) => _load(id);
  Future<void> _load(String? id) async {
    _selectedSpecialtyId = id;
    _doctors = const [];
    final token = beginRequest();
    try {
      final values = id == null
          ? await _repository.getDoctors()
          : await _repository.getDoctorsBySpecialty(id);
      if (!isCurrent(token)) return;
      _doctors = List.unmodifiable(values);
      setState(values.isEmpty ? ViewState.empty : ViewState.success);
    } catch (error) {
      if (isCurrent(token)) setState(ViewState.error, error);
    }
  }
}
