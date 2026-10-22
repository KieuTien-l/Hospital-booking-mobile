import 'dart:async';

import '../../../../core/state/view_state.dart';
import '../../../auth/data/models/user_model.dart';
import '../../domain/repositories/admin_account_repository.dart';

class AdminAccountController extends ViewStateController {
  AdminAccountController(this._repository);

  final AdminAccountRepository _repository;
  StreamSubscription<List<UserModel>>? _pendingSubscription;
  int _pendingRequest = 0;
  List<UserModel> _pendingAccounts = const [];
  List<UserModel> get pendingAccounts => _pendingAccounts;

  Future<void> loadPendingAccounts() async {
    final pendingRequest = ++_pendingRequest;
    final request = beginRequest();
    try {
      await _pendingSubscription?.cancel();
      _pendingSubscription = _repository.watchPendingAccounts().listen(
        (accounts) {
          if (pendingRequest != _pendingRequest) return;
          _pendingAccounts = List.unmodifiable(accounts);
          setState(accounts.isEmpty ? ViewState.empty : ViewState.success);
        },
        onError: (Object error) {
          if (pendingRequest == _pendingRequest) {
            _pendingAccounts = const [];
            setState(ViewState.error, error);
          }
        },
      );
    } catch (error) {
      if (isCurrent(request)) setState(ViewState.error, error);
    }
  }

  Future<UserModel?> approveAccount(String accountId) =>
      _review(() => _repository.approveAccount(accountId));

  Future<UserModel?> rejectAccount(String accountId) =>
      _review(() => _repository.rejectAccount(accountId));

  Future<UserModel?> _review(Future<UserModel> Function() action) async {
    final request = beginRequest();
    try {
      final account = await action();
      if (isCurrent(request)) setState(ViewState.success);
      return account;
    } catch (error) {
      if (isCurrent(request)) setState(ViewState.error, error);
      return null;
    }
  }

  @override
  void dispose() {
    _pendingRequest++;
    _pendingAccounts = const [];
    _pendingSubscription?.cancel();
    super.dispose();
  }
}
