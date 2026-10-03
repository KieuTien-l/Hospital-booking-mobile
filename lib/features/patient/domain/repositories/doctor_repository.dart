import '../../../../core/models/doctor_model.dart';

/// Reads doctors and their specialty relationship.
abstract class DoctorRepository {
  Future<List<Doctor>> getDoctors();

  Future<Doctor?> getDoctorById(String doctorId);

  Future<List<Doctor>> getDoctorsBySpecialty(String specialtyId);
}
