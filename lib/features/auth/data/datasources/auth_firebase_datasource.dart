import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/entities/user_entity.dart';
import '../../../profile/data/models/patient_model.dart';
import '../models/user_model.dart';
import '../exceptions/api_exception.dart';
import '../../domain/exceptions/auth_exception.dart';
import 'auth_firestore_rest_datasource.dart';

class AuthFirebaseDatasource {
  AuthFirebaseDatasource({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    AuthFirestoreRestDatasource? restDatasource,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _restDatasource = restDatasource ?? AuthFirestoreRestDatasource();

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final AuthFirestoreRestDatasource _restDatasource;

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

  Future<UserModel> _getUserProfile(User firebaseUser) async {
    try {
      final idToken = await firebaseUser.getIdToken();
      if (idToken == null || idToken.isEmpty) {
        throw const AuthException('Unable to authenticate this account.');
      }
      return await _restDatasource.getUser(
        userId: firebaseUser.uid,
        idToken: idToken,
      );
    } on AuthException {
      rethrow;
    } on ApiException catch (error) {
      throw AuthException(error.message);
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
}
