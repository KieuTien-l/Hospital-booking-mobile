import '../entities/doctor.dart';

/// Reads doctors and their specialty relationship.
abstract class DoctorRepository {
  Future<List<Doctor>> getDoctors();

  Future<Doctor?> getDoctorById(String doctorId);

  /// Finds the active doctor profile for a Firebase Authentication user.
  Future<Doctor?> getDoctorByUserId(String userId);

  Future<List<Doctor>> getDoctorsBySpecialty(String specialtyId);
}
