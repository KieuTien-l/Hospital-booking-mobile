import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../core/utils/model_value_parser.dart';
import '../data/admin_repository.dart';
import 'admin_sections.dart';

class AdminDataset {
  const AdminDataset({
    this.records = const [],
    this.loading = false,
    this.error,
  });
  final List<AdminRecord> records;
  final bool loading;
  final String? error;
  bool get useDemo => !loading && error == null && records.isEmpty;
  String get sourceLabel => loading
      ? 'Đang tải'
      : error != null
      ? 'Chưa đọc được'
      : useDemo
      ? 'Chưa có bản ghi'
      : 'Sẵn sàng';
}

class AdminController extends ChangeNotifier {
  AdminController(this.repository);
  final AdminRepository repository;
  final Map<String, AdminDataset> _datasets = {};
  final Map<String, StreamSubscription<List<AdminRecord>>> _subscriptions = {};
  bool _disposed = false;

  AdminDataset dataset(String collection) =>
      _datasets[collection] ?? const AdminDataset(loading: true);

  void start() {
    for (final section in adminSections) {
      if (section.collection != null) _listen(section.collection!);
    }
    _listen('ADMIN_NOTES');
  }

  Future<void> retry(String collection) async {
    await _subscriptions.remove(collection)?.cancel();
    if (_disposed) return;
    _listen(collection);
    notifyListeners();
  }

  void _listen(String collection) {
    _datasets[collection] = const AdminDataset(loading: true);
    _subscriptions[collection] = repository
        .watch(collection)
        .listen(
          (records) {
            if (_disposed) return;
            _datasets[collection] = AdminDataset(records: records);
            notifyListeners();
          },
          onError: (Object error) {
            if (_disposed) return;
            _datasets[collection] = AdminDataset(
              error:
                  error is FirebaseException &&
                      error.code == 'permission-denied'
                  ? 'Tài khoản hiện tại chưa được cấp quyền đọc mục này trong Firestore Rules.'
                  : error is AdminDataException
                  ? error.message
                  : 'Không tải được dữ liệu Firebase. Kiểm tra kết nối và thử lại.',
            );
            notifyListeners();
          },
        );
  }

  String referenceName(String field, Object? value) {
    final collection = switch (field) {
      'patientId' => 'BENH_NHAN',
      'doctorId' => 'BAC_SI',
      'specialtyId' => 'CHUYEN_KHOA',
      'appointmentId' => 'LICH_HEN',
      'workScheduleId' => 'LICH_LAM_VIEC',
      'timeSlotId' => 'CA_KHAM',
      'paymentId' => 'THANH_TOAN',
      'userId' || 'authUserId' || 'assigneeId' || 'actorId' => 'TAI_KHOAN',
      _ => null,
    };
    final id = readReferenceId(value);
    if (collection != null) {
      for (final record in dataset(collection).records) {
        if (record.id == id) {
          return readString(
            record.data['fullName'] ?? record.data['name'],
            fallback: switch (field) {
              'appointmentId' => 'Lịch hẹn',
              'workScheduleId' => 'Lịch làm việc',
              'timeSlotId' => 'Ca khám',
              'paymentId' => 'Thanh toán',
              _ => id,
            },
          );
        }
      }
    }
    return id;
  }

  @override
  void dispose() {
    _disposed = true;
    for (final subscription in _subscriptions.values) {
      unawaited(subscription.cancel());
    }
    super.dispose();
  }
}

/// Local fixtures for empty collections or an explicitly requested UI preview.
List<AdminRecord> adminDemoRecords(AdminSection section) {
  final values = <String, dynamic>{
    'fullName': 'Nguyễn Minh An (demo)',
    'name': 'Nội tổng quát (demo)',
    'patientId': 'Bệnh nhân minh họa',
    'doctorId': 'Bác sĩ minh họa',
    'specialtyId': 'Chuyên khoa minh họa',
    'email': 'demo@example.com',
    'phone': '0900 000 000',
    'appointmentDate': DateTime(2026, 10, 20),
    'workDate': DateTime(2026, 10, 20),
    'startTime': '08:00',
    'endTime': '08:30',
    'status': switch (section.collection) {
      'LICH_HEN' => 'PENDING',
      'CA_KHAM' => 'AVAILABLE',
      'THANH_TOAN' => 'PAID',
      _ => 'ACTIVE',
    },
    'capacity': 5,
    'bookedCount': 2,
    'amount': 150000,
    'consultationFee': 150000,
    'rating': 5,
    'title': 'Thông tin minh họa',
    'content': 'Nội dung demo để xem trước giao diện.',
    'description': 'Chuyên khoa minh họa',
    'paymentMethod': 'Chuyển khoản',
    'transactionCode': 'DEMO-001',
    'role': 'patient',
    'isActive': true,
    'note': 'Dữ liệu cục bộ, không lưu Firebase.',
  };
  return [
    AdminRecord('DEMO-001', {
      for (final field in section.columns.keys)
        field: values[field] ?? 'Minh họa',
      'isTestData': true,
    }),
  ];
}
