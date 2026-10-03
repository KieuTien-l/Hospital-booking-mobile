import '../../../../core/models/specialty_model.dart';

/// Reads the specialties available for a patient to select.
abstract class SpecialtyRepository {
  Stream<List<Specialty>> watchSpecialties();
}
