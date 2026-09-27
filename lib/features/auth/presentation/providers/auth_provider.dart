import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthProvider extends ChangeNotifier {
  // The public constructor keeps the dependency name descriptive at call sites.
  // ignore: prefer_initializing_formals
  AuthProvider({required AuthRepository authRepo}) : _authRepo = authRepo {
    _authSubscription = _authRepo.authStateChanges.listen(_onAuthStateChanged);
    _restoreSession();
  }

  final AuthRepository _authRepo;
  late final StreamSubscription<String?> _authSubscription;

  AuthStatus _status = AuthStatus.initial;
  UserEntity? _currentUser;
  String? _errorMessage;

  AuthStatus get status => _status;
  UserEntity? get currentUser => _currentUser;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _status == AuthStatus.loading;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  Future<void> _restoreSession() async {
    _status = AuthStatus.loading;
    notifyListeners();

    try {
      _currentUser = await _authRepo.getCurrentUser();
      _status = _currentUser == null
          ? AuthStatus.unauthenticated
          : AuthStatus.authenticated;
      _errorMessage = null;
    } catch (error) {
      _currentUser = null;
      _status = AuthStatus.error;
      _errorMessage = _messageFrom(error);
    }
    notifyListeners();
  }

  void _onAuthStateChanged(String? userId) {
    if (userId == null) {
      if (_status == AuthStatus.loading) return;
      _currentUser = null;
      _status = AuthStatus.unauthenticated;
      _errorMessage = null;
      notifyListeners();
      return;
    }
    _restoreSession();
  }

  Future<void> login({required String email, required String password}) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      _currentUser = await _authRepo.login(email: email, password: password);
      _status = AuthStatus.authenticated;
    } catch (error) {
      _currentUser = null;
      _status = AuthStatus.error;
      _errorMessage = _messageFrom(error);
    }
    notifyListeners();
  }

  Future<bool> register({
    required String email,
    required String password,
    required String fullName,
    required String phone,
  }) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      await _authRepo.register(
        email: email,
        password: password,
        fullName: fullName,
        phone: phone,
      );
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return true;
    } catch (error) {
      _status = AuthStatus.error;
      _errorMessage = _messageFrom(error);
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    _status = AuthStatus.loading;
    notifyListeners();

    try {
      await _authRepo.logout();
    } catch (_) {
      // Local state must still be cleared if the remote sign-out call fails.
    }
    _currentUser = null;
    _status = AuthStatus.unauthenticated;
    _errorMessage = null;
    notifyListeners();
  }

  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  String _messageFrom(Object error) {
    return error.toString().replaceFirst('Exception: ', '');
  }
}
