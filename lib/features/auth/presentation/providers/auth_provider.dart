import 'package:flutter/foundation.dart';
import '../../../../core/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../data/datasources/auth_firebase_datasource.dart';
import '../../data/repositories/auth_repository_impl.dart';

enum AuthStatus {
  initial,
  loading,
  authenticated,
  unauthenticated,
  error,
}

class AuthProvider extends ChangeNotifier {
  final AuthRepository _authRepo;

  AuthStatus _status = AuthStatus.initial;
  UserEntity? _currentUser;
  String? _errorMessage;

  AuthProvider({AuthRepository? authRepo})
      : _authRepo = authRepo ?? AuthRepositoryImpl(AuthFirebaseDatasource()) {
    _init();
  }

  AuthStatus get status => _status;
  UserEntity? get currentUser => _currentUser;
  String? get errorMessage => _errorMessage;

  bool get isLoading => _status == AuthStatus.loading;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  void _init() {
    _status = AuthStatus.unauthenticated;
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await _authRepo.login(
        email: email,
        password: password,
      );
      _currentUser = user;
      _status = AuthStatus.authenticated;
      notifyListeners();
    } catch (e) {
      _currentUser = null;
      _status = AuthStatus.error;
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _status = AuthStatus.loading;
    notifyListeners();

    try {
      await _authRepo.logout();
    } catch (_) {}

    _currentUser = null;
    _status = AuthStatus.unauthenticated;
    _errorMessage = null;
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
    } catch (e) {
      _status = AuthStatus.error;
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }
}
