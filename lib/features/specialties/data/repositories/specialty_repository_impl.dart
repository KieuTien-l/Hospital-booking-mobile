import '../../domain/entities/specialty.dart';
import '../../domain/repositories/specialty_repository.dart';
import '../datasources/specialty_firebase_datasource.dart';

class SpecialtyRepositoryImpl implements SpecialtyRepository {
  SpecialtyRepositoryImpl(SpecialtyFirebaseDatasource datasource)
    : _datasource = datasource;

  final SpecialtyFirebaseDatasource _datasource;

  @override
  Stream<List<Specialty>> watchSpecialties() => _datasource.watchSpecialties();
}
