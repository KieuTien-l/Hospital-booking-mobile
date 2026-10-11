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

  /// Sends Firebase's password-reset email to an already registered account.
  Future<void> sendPasswordResetEmail({required String email});

  Future<void> logout();
}
