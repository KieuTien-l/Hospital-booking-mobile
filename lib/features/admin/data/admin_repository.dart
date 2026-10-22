import 'package:cloud_firestore/cloud_firestore.dart';

class AdminRecord {
  const AdminRecord(this.id, this.data);
  final String id;
  final Map<String, dynamic> data;

  bool get isSample =>
      data['isTestData'] == true ||
      data.containsKey('seedVersion') ||
      RegExp(
        r'demo|seed|sample|test',
        caseSensitive: false,
      ).hasMatch('${data['source'] ?? ''}');
}

abstract class AdminRepository {
  Stream<List<AdminRecord>> watch(String collection);
}

/// Read-only client SDK access. Firebase Auth and existing rules still apply.
class FirestoreAdminRepository implements AdminRepository {
  FirestoreAdminRepository({this.firestore});

  final FirebaseFirestore? firestore;

  @override
  Stream<List<AdminRecord>> watch(String collection) async* {
    yield* (firestore ?? FirebaseFirestore.instance)
        .collection(collection)
        .snapshots(includeMetadataChanges: true)
        .map((snapshot) {
          // Cached documents must not be presented as a verified live result.
          if (snapshot.metadata.isFromCache) {
            throw const AdminDataException(
              'Chưa xác nhận được dữ liệu từ máy chủ. Kiểm tra kết nối mạng.',
            );
          }
          return snapshot.docs
              .map((doc) => AdminRecord(doc.id, doc.data()))
              .toList(growable: false);
        });
  }
}

class AdminDataException implements Exception {
  const AdminDataException(this.message);
  final String message;
}
