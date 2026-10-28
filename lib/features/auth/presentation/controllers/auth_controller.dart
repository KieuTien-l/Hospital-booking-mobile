import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';

enum AuthStatus {
  initial,
  loading,
  authenticated,

  /// The credentials are valid, but an administrator has disabled access.
  locked,
  unauthenticated,
  error,
}

class AuthController extends ChangeNotifier {
  // The public constructor keeps the dependency name descriptive at call sites.
  // ignore: prefer_initializing_formals
  AuthController({required AuthRepository authRepo}) : _authRepo = authRepo {
    _authSubscription = _authRepo.authStateChanges.listen(_onAuthStateChanged);
    _restoreSession();
  }

  final AuthRepository _authRepo;
  late final StreamSubscription<String?> _authSubscription;

  AuthStatus _status = AuthStatus.initial;
  UserEntity? _currentUser;
  String? _errorMessage;
  bool _restoringSession = false;
  bool _refreshAfterRestore = false;
  // Every asynchronous auth operation captures this value.  A response that
  // started before logout must never be allowed to restore a signed-in UI.
  var _sessionEpoch = 0;

  AuthStatus get status => _status;
  UserEntity? get currentUser => _currentUser;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _status == AuthStatus.loading;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get isLocked => _status == AuthStatus.locked;

  Future<void> _restoreSession() async {
    if (_restoringSession) return;
    final epoch = _sessionEpoch;
    _restoringSession = true;
    _status = AuthStatus.loading;
    notifyListeners();

    try {
      final user = await _authRepo.getCurrentUser();
      if (epoch != _sessionEpoch) return;
      _applyLoadedUser(user);
    } catch (error) {
      if (epoch != _sessionEpoch) return;
      _currentUser = null;
      _status = AuthStatus.error;
      _errorMessage = _messageFrom(error);
    } finally {
      // A logout can invalidate this restore.  It still has to release the
      // guard so a later sign-in event can start a fresh restore.
      _restoringSession = false;
    }
    if (epoch == _sessionEpoch) notifyListeners();
    if (_refreshAfterRestore && epoch == _sessionEpoch) {
      _refreshAfterRestore = false;
      _restoreSession();
    }
  }

  void _onAuthStateChanged(String? userId) {
    if (userId == null) {
      _sessionEpoch++;
      _currentUser = null;
      _status = AuthStatus.unauthenticated;
      _errorMessage = null;
      notifyListeners();
      return;
    }
    // Login and registration already load their profile explicitly. Ignoring
    // this duplicate event while loading prevents an old restore from
    // overwriting the final signed-out state after registration.
    if (_status == AuthStatus.loading || _restoringSession) {
      // Firebase can emit the auth event before the first server profile read
      // completes. Reload once it settles so account changes are never lost.
      _refreshAfterRestore = true;
      return;
    }
    _restoreSession();
  }

  Future<void> login({required String email, required String password}) async {
    final epoch = ++_sessionEpoch;
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await _authRepo.login(email: email, password: password);
      if (epoch != _sessionEpoch) return;
      _applyLoadedUser(user);
    } catch (error) {
      if (epoch != _sessionEpoch) return;
      _currentUser = null;
      _status = AuthStatus.error;
      _errorMessage = _messageFrom(error);
    }
    if (epoch == _sessionEpoch) notifyListeners();
  }

  Future<bool> register({
    required String email,
    required String password,
    required String fullName,
    required String phone,
  }) async {
    final epoch = ++_sessionEpoch;
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      _currentUser = await _authRepo.register(
        email: email,
        password: password,
        fullName: fullName,
        phone: phone,
      );
      if (epoch != _sessionEpoch) return false;
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } catch (error) {
      if (epoch != _sessionEpoch) return false;
      _status = AuthStatus.error;
      _errorMessage = _messageFrom(error);
      notifyListeners();
      return false;
    }
  }

  /// Keeps the signed-in session intact while requesting Firebase's reset
  /// email. The page owns its short-lived submit/loading UI state.
  Future<String?> sendPasswordResetEmail(String email) async {
    try {
      await _authRepo.sendPasswordResetEmail(email: email);
      return null;
    } catch (error) {
      return _messageFrom(error);
    }
  }

  Future<void> logout() async {
    ++_sessionEpoch;
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

  void _applyLoadedUser(UserEntity? user) {
    if (user == null) {
      _currentUser = null;
      _status = AuthStatus.unauthenticated;
      _errorMessage = null;
      return;
    }
    if (!user.isActive) {
      // Do not expose the disabled profile to pages that could continue using
      // it. The Firebase session is retained only so the user can explicitly
      // sign out from the lock screen; Rules and Workers reject every
      // protected operation while the account is inactive.
      _currentUser = null;
      _status = AuthStatus.locked;
      _errorMessage = 'Tài khoản của bạn đã bị khóa. Vui lòng liên hệ quản trị viên để được hỗ trợ.';
      return;
    }
    _currentUser = user;
    _status = AuthStatus.authenticated;
    _errorMessage = null;
  }
}
