import 'dart:async';

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

      // The UI needs the profile, including `isActive`, to distinguish a
      // deliberately locked account from a failed sign-in.  AuthController
      // then routes a locked profile to the dedicated lock screen; Firestore
      // Rules and the Worker still deny all protected operations.
      return await _getUserProfile(firebaseUser);
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
    User? createdUser;
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final firebaseUser = credential.user;
      if (firebaseUser == null) {
        throw const AuthException('Unable to create this account.');
      }
      createdUser = firebaseUser;

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
      return user;
    } on AuthException {
      rethrow;
    } on FirebaseAuthException catch (error) {
      throw AuthException(_registerMessage(error));
    } on FirebaseException catch (error) {
      // `createUserWithEmailAndPassword` succeeds before Firestore validates
      // the profile.  Remove that brand-new Auth account when the batch is
      // rejected so the email can be corrected and registered again.
      await _discardFailedRegistration(createdUser);
      throw AuthException(_profileCreateMessage(error));
    } catch (_) {
      await _discardFailedRegistration(createdUser);
      throw const AuthException('Unable to register. Please try again.');
    }
  }

  Future<void> _discardFailedRegistration(User? createdUser) async {
    if (createdUser != null) {
      try {
        await createdUser.delete();
      } catch (_) {
        // Signing out still protects the current session if the network drops
        // before Firebase can remove the just-created account.
      }
    }
    await _auth.signOut();
  }

  String _profileCreateMessage(FirebaseException error) {
    switch (error.code) {
      case 'permission-denied':
        return 'Không thể lưu hồ sơ tài khoản. Vui lòng kiểm tra lại thông tin rồi thử lại.';
      case 'unavailable':
        return 'Không thể kết nối để tạo hồ sơ. Vui lòng kiểm tra mạng rồi thử lại.';
      default:
        return 'Không thể tạo hồ sơ tài khoản. Vui lòng thử lại.';
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
          .get(const GetOptions(source: Source.server))
          // A login must not leave the screen loading forever if Firestore is
          // offline. We cannot safely decide whether the account is locked
          // without the server profile, so surface a clear retryable error.
          .timeout(const Duration(seconds: 15));
      if (!account.exists) {
        throw const AuthException('Không tìm thấy hồ sơ tài khoản.');
      }
      return UserModel.fromFirestore(account);
    } on AuthException {
      rethrow;
    } on TimeoutException {
      throw const AuthException(
        'Không thể kiểm tra trạng thái tài khoản. Vui lòng kiểm tra mạng rồi thử lại.',
      );
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
