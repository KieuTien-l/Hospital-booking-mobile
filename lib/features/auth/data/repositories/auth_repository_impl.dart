import '../../../../core/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_firebase_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthFirebaseDatasource _datasource;

  AuthRepositoryImpl(this._datasource);

  @override
  Stream<String?> get authStateChanges => _datasource.authStateChanges;

  @override
  Future<UserEntity?> getCurrentUser() async {
    // Để lấy thông tin user hiện tại, ta có thể kết hợp authStateChanges hoặc giữ uid
    // Tạm thời implementation này phụ thuộc vào Firebase logic, có thể truyền uid vào nếu cần
    throw UnimplementedError('Sử dụng provider để quản lý state thay vì gọi trực tiếp');
  }

  @override
  Future<UserEntity> login({
    required String email,
    required String password,
  }) async {
    return await _datasource.login(email, password);
  }

  @override
  Future<UserEntity> register({
    required String email,
    required String password,
    required String fullName,
    required String phone,
  }) async {
    return await _datasource.register(email, password, fullName, phone);
  }

  @override
  Future<void> logout() async {
    await _datasource.logout();
  }
}
