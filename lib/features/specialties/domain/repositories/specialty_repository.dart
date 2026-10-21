import '../entities/specialty.dart';

/// Reads the specialties available for a patient to select.
abstract class SpecialtyRepository {
  Stream<List<Specialty>> watchSpecialties();

  /// Includes inactive specialties for administration and data validation.
  ///
  /// The default preserves compatibility for non-Firestore implementations;
  /// production repositories override it with the full collection stream.
  Stream<List<Specialty>> watchAllSpecialties() => watchSpecialties();
}
