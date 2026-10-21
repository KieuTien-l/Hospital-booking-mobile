import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../auth/data/models/user_model.dart';
import '../../domain/exceptions/admin_management_exception.dart';
import '../../domain/repositories/admin_account_repository.dart';

class AdminAccountRepositoryImpl implements AdminAccountRepository {
  AdminAccountRepositoryImpl({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  CollectionReference<Map<String, dynamic>> get _accounts =>
      _firestore.collection('TAI_KHOAN');

  @override
  Stream<List<UserModel>> watchPendingAccounts() => _accounts
      .where('status', isEqualTo: 'PENDING')
      .snapshots()
      .map(_usersFromSnapshot);

  @override
  Stream<List<UserModel>> watchApprovedAccounts() => _accounts
      .where('status', whereIn: const ['APPROVED', 'ACTIVE'])
      .snapshots()
      .map(_usersFromSnapshot);

  @override
  Future<UserModel> approveAccount(String accountId) =>
      _review(accountId, approved: true);

  @override
  Future<UserModel> rejectAccount(String accountId) =>
      _review(accountId, approved: false);

  Future<UserModel> _review(String accountId, {required bool approved}) async {
    final id = accountId.trim();
    if (id.isEmpty) {
      throw const AdminManagementException('Mã tài khoản là bắt buộc.');
    }
    final reference = _accounts.doc(id);
    return _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);
      if (!snapshot.exists) {
        throw const AdminManagementException('Tài khoản không tồn tại.');
      }
      final account = UserModel.fromFirestore(snapshot);
      if ((account.status ?? '').toUpperCase() != 'PENDING') {
        throw const AdminManagementException(
          'Chỉ tài khoản đang chờ mới có thể được duyệt hoặc từ chối.',
        );
      }
      final status = approved ? 'APPROVED' : 'REJECTED';
      transaction.update(reference, {
        'status': status,
        'isActive': approved,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return UserModel(
        id: account.id,
        email: account.email,
        fullName: account.fullName,
        phone: account.phone,
        role: account.role,
        isActive: approved,
        department: account.department,
        accountKey: account.accountKey,
        permission: account.permission,
        status: status,
        createdAt: account.createdAt,
        updatedAt: DateTime.now(),
      );
    });
  }

  List<UserModel> _usersFromSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final users = snapshot.docs.map(UserModel.fromFirestore).toList();
    users.sort((left, right) => left.fullName.compareTo(right.fullName));
    return List.unmodifiable(users);
  }
}
