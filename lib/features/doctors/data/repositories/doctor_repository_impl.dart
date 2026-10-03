import '../../domain/entities/doctor.dart';
import '../../domain/repositories/doctor_repository.dart';
import '../datasources/doctor_firebase_datasource.dart';

class DoctorRepositoryImpl implements DoctorRepository {
  DoctorRepositoryImpl(DoctorFirebaseDatasource datasource)
    : _datasource = datasource;

  final DoctorFirebaseDatasource _datasource;

  @override
  Future<List<Doctor>> getDoctors() => _datasource.getDoctors();

  @override
  Future<Doctor?> getDoctorById(String doctorId) =>
      _datasource.getDoctorById(doctorId);

  @override
  Future<List<Doctor>> getDoctorsBySpecialty(String specialtyId) =>
      _datasource.getDoctorsBySpecialty(specialtyId);
}
