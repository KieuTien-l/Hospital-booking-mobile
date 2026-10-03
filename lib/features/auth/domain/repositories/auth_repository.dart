import '../entities/user_entity.dart';

abstract class AuthRepository {
  Stream<String?> get authStateChanges;

  Future<UserEntity?> getCurrentUser();

  Future<UserRole?> getUserRole();

  Future<UserEntity> login({required String email, required String password});

  Future<UserEntity> register({
    required String email,
    required String password,
    required String fullName,
    required String phone,
  });

  Future<void> logout();
}
