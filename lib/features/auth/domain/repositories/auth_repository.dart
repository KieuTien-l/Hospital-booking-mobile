import '../../../../core/entities/user_entity.dart';

abstract class AuthRepository {
  /// Stream theo dõi trạng thái đăng nhập (trả về uid nếu đã đăng nhập, null nếu chưa)
  Stream<String?> get authStateChanges;

  /// Lấy thông tin user hiện tại từ Firestore
  Future<UserEntity?> getCurrentUser();

  /// Đăng nhập
  Future<UserEntity> login({
    required String email,
    required String password,
  });

  /// Đăng ký (Mặc định role là patient)
  Future<UserEntity> register({
    required String email,
    required String password,
    required String fullName,
    required String phone,
  });

  /// Đăng xuất
  Future<void> logout();
}
