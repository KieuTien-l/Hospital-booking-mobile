import '../../../auth/data/models/user_model.dart';

/// Legacy account-review contract retained for isolated historical tests.
/// New patient registration never uses this workflow.
abstract class AdminAccountRepository {
  Stream<List<UserModel>> watchPendingAccounts();

  Stream<List<UserModel>> watchApprovedAccounts();

  Future<UserModel> approveAccount(String accountId);

  Future<UserModel> rejectAccount(String accountId);
}
