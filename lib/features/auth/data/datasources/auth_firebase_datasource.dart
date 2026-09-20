import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/entities/user_entity.dart';

class AuthFirebaseDatasource {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<String?> get authStateChanges {
    return _auth.authStateChanges().map((user) => user?.uid);
  }

  Future<UserModel?> getUser(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (doc.exists) {
      return UserModel.fromFirestore(doc);
    }
    return null;
  }

  Future<UserModel> login(String email, String password) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      final userModel = await getUser(cred.user!.uid);
      if (userModel == null) {
        throw Exception("Không tìm thấy thông tin tài khoản trên hệ thống.");
      }
      
      if (!userModel.isActive) {
        await _auth.signOut();
        throw Exception("Tài khoản của bạn đã bị khóa hoặc không hoạt động.");
      }
      
      return userModel;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' || e.code == 'invalid-email') {
        throw Exception("Tài khoản không tồn tại hoặc email không hợp lệ.");
      } else if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        throw Exception("Sai mật khẩu hoặc thông tin đăng nhập không hợp lệ.");
      } else if (e.code == 'user-disabled') {
        throw Exception("Tài khoản của bạn đã bị vô hiệu hóa.");
      }
      throw Exception("Lỗi đăng nhập: ${e.message}");
    } catch (e) {
      throw Exception("Lỗi không xác định: ${e.toString()}");
    }
  }

  Future<UserModel> register(
    String email,
    String password,
    String fullName,
    String phone,
  ) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = cred.user!.uid;

      final userModel = UserModel(
        id: uid,
        email: email,
        fullName: fullName,
        phone: phone,
        role: UserRole.patient,
        isActive: true,
      );

      await _firestore.collection('users').doc(uid).set(userModel.toMap());

      return userModel;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'weak-password') {
        throw Exception("Mật khẩu quá yếu. Vui lòng chọn mật khẩu an toàn hơn.");
      } else if (e.code == 'email-already-in-use') {
        throw Exception("Email này đã được sử dụng. Vui lòng dùng email khác.");
      } else if (e.code == 'invalid-email') {
        throw Exception("Email sai định dạng.");
      }
      throw Exception("Lỗi đăng ký: ${e.message}");
    } catch (e) {
      throw Exception("Lỗi mạng hoặc hệ thống: ${e.toString()}");
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
  }
}
