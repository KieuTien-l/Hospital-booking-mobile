import '../../../../core/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_firebase_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._datasource);

  final AuthFirebaseDatasource _datasource;

  @override
  Stream<String?> get authStateChanges => _datasource.authStateChanges;

  @override
  Future<UserEntity?> getCurrentUser() => _datasource.getCurrentUser();

  @override
  Future<UserRole?> getUserRole() => _datasource.getUserRole();

  @override
  Future<UserEntity> login({required String email, required String password}) {
    return _datasource.login(email, password);
  }

  @override
  Future<UserEntity> register({
    required String email,
    required String password,
    required String fullName,
    required String phone,
  }) {
    return _datasource.register(email, password, fullName, phone);
  }

  @override
  Future<void> logout() => _datasource.logout();
}
