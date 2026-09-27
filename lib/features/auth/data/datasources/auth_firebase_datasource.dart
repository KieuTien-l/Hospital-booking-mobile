import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/entities/user_entity.dart';
import '../../../../core/models/user_model.dart';
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
    return user == null ? null : getUser(user.uid);
  }

  Future<UserRole?> getUserRole() async {
    return (await getCurrentUser())?.role;
  }

  Future<UserModel?> getUser(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.exists ? UserModel.fromFirestore(doc) : null;
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

      final user = await getUser(firebaseUser.uid);
      if (user == null) {
        await _auth.signOut();
        throw const AuthException('Account profile was not found.');
      }
      if (!user.isActive) {
        await _auth.signOut();
        throw const AuthException('This account is inactive.');
      }
      return user;
    } on AuthException {
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
      );
      await _firestore
          .collection('users')
          .doc(firebaseUser.uid)
          .set(user.toFirestoreCreate());

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

  String _loginMessage(FirebaseAuthException error) {
    switch (error.code) {
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
