import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/entities/user_entity.dart';
import '../../../profile/data/models/patient_model.dart';
import '../models/user_model.dart';
import '../../domain/exceptions/auth_exception.dart';

class AuthFirebaseDatasource {
  AuthFirebaseDatasource({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  Stream<String?> get authStateChanges {
    return _auth.authStateChanges().map((user) => user?.uid);
  }

  Future<UserModel?> getCurrentUser() async {
    final user = _auth.currentUser;
    return user == null ? null : _getUserProfile(user);
  }

  Future<UserRole?> getUserRole() async {
    return (await getCurrentUser())?.role;
  }

  Future<UserModel> login(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final firebaseUser = credential.user;
      if (firebaseUser == null) {
        throw const AuthException('Unable to authenticate this account.');
      }

      final user = await _getUserProfile(firebaseUser);
      if (!user.isActive) {
        await _auth.signOut();
        throw const AuthException('This account is inactive.');
      }
      return user;
    } on AuthException {
      await _auth.signOut();
      rethrow;
    } on FirebaseAuthException catch (error) {
      throw AuthException(_loginMessage(error));
    } on FirebaseException {
      throw const AuthException('Unable to load the account profile.');
    } catch (_) {
      throw const AuthException('Unable to sign in. Please try again.');
    }
  }

  Future<UserModel> register(
    String email,
    String password,
    String fullName,
    String phone,
  ) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final firebaseUser = credential.user;
      if (firebaseUser == null) {
        throw const AuthException('Unable to create this account.');
      }

      final user = UserModel(
        id: firebaseUser.uid,
        email: email,
        fullName: fullName,
        phone: phone,
        role: UserRole.patient,
        isActive: true,
        accountKey: firebaseUser.uid,
        permission: 'PATIENT',
        status: 'ACTIVE',
      );
      final patient = PatientModel(
        id: firebaseUser.uid,
        authUserId: firebaseUser.uid,
        fullName: fullName,
        phone: phone,
        email: email,
        isActive: true,
      );
      final batch = _firestore.batch();
      batch.set(
        _firestore.collection('TAI_KHOAN').doc(firebaseUser.uid),
        user.toFirestoreCreate(),
      );
      batch.set(
        _firestore.collection(PatientModel.collectionName).doc(patient.id),
        patient.toFirestoreCreate(),
      );
      await batch.commit();

      await _auth.signOut();
      return user;
    } on AuthException {
      rethrow;
    } on FirebaseAuthException catch (error) {
      throw AuthException(_registerMessage(error));
    } on FirebaseException {
      await _auth.signOut();
      throw const AuthException('Unable to create the account profile.');
    } catch (_) {
      await _auth.signOut();
      throw const AuthException('Unable to register. Please try again.');
    }
  }

  Future<void> logout() => _auth.signOut();

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (error) {
      throw AuthException(_passwordResetMessage(error));
    } catch (_) {
      throw const AuthException(
        'Không thể gửi liên kết đặt lại mật khẩu. Vui lòng thử lại.',
      );
    }
  }

  Future<UserModel> _getUserProfile(User firebaseUser) async {
    try {
      // Keep account reads on the Firebase SDK channel. The earlier REST
      // endpoint is rate-limited separately and can return HTTP 429 after
      // repeated app restarts even though the user has authenticated.
      final account = await _firestore
          .collection('TAI_KHOAN')
          .doc(firebaseUser.uid)
          .get(const GetOptions(source: Source.server));
      if (!account.exists) {
        throw const AuthException('Không tìm thấy hồ sơ tài khoản.');
      }
      return UserModel.fromFirestore(account);
    } on AuthException {
      rethrow;
    } on FirebaseException catch (error) {
      throw AuthException(_profileLoadMessage(error));
    }
  }

  String _profileLoadMessage(FirebaseException error) {
    switch (error.code) {
      case 'unavailable':
        return 'Không thể kết nối để tải hồ sơ tài khoản. Vui lòng kiểm tra mạng rồi thử lại.';
      case 'permission-denied':
        return 'Bạn không có quyền truy cập hồ sơ tài khoản.';
      case 'resource-exhausted':
        return 'Máy chủ đang bận. Vui lòng chờ một lát rồi thử lại.';
      default:
        return 'Không thể tải hồ sơ tài khoản. Vui lòng thử lại.';
    }
  }

  String _loginMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'network-request-failed':
        return 'Không thể kết nối đến máy chủ đăng nhập. Vui lòng kiểm tra kết nối Internet rồi thử lại.';
      case 'too-many-requests':
        return 'Bạn đã thử đăng nhập quá nhiều lần. Vui lòng chờ một lúc rồi thử lại.';
      case 'user-not-found':
      case 'invalid-email':
        return 'The email address is invalid or is not registered.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'The email address or password is incorrect.';
      case 'user-disabled':
        return 'This account has been disabled.';
      default:
        return 'Unable to sign in. Please try again.';
    }
  }

  String _registerMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'weak-password':
        return 'The password is too weak.';
      case 'email-already-in-use':
        return 'This email address is already in use.';
      case 'invalid-email':
        return 'The email address is invalid.';
      default:
        return 'Unable to register. Please try again.';
    }
  }

  String _passwordResetMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-email':
        return 'Email không hợp lệ.';
      case 'user-not-found':
        // Firebase can intentionally hide whether an email exists. The
        // neutral message is safer for both cases.
        return 'Nếu email đã đăng ký, liên kết đặt lại mật khẩu sẽ được gửi.';
      case 'too-many-requests':
        return 'Bạn đã yêu cầu quá nhiều lần. Vui lòng chờ một lúc rồi thử lại.';
      case 'network-request-failed':
        return 'Không thể kết nối Internet. Vui lòng kiểm tra mạng rồi thử lại.';
      default:
        return 'Không thể gửi liên kết đặt lại mật khẩu. Vui lòng thử lại.';
    }
  }
}
