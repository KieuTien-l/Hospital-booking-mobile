import '../../../auth/data/models/user_model.dart';

/// Administrator-only account approval workflow.
abstract class AdminAccountRepository {
  Stream<List<UserModel>> watchPendingAccounts();

  Stream<List<UserModel>> watchApprovedAccounts();

  /// Moves one pending account to APPROVED. Repeating the operation fails.
  Future<UserModel> approveAccount(String accountId);

  /// Moves one pending account to REJECTED. Repeating the operation fails.
  Future<UserModel> rejectAccount(String accountId);
}
