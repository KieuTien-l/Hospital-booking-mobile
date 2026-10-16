import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../appointments/data/models/appointment_model.dart';
import '../../../doctors/data/models/doctor_model.dart';
import '../../../doctors/data/models/time_slot_model.dart';
import '../../../doctors/data/models/work_schedule_model.dart';
import '../../domain/entities/doctor_workspace.dart';
import '../../domain/repositories/doctor_workspace_repository.dart';

/// Uses a scoped backend projection; never reads unrestricted patient profiles.
class HttpDoctorWorkspaceRepository implements DoctorWorkspaceRepository {
  HttpDoctorWorkspaceRepository({
    required this.baseUrl,
    required this.tokenProvider,
    this.onUnauthorized,
    http.Client? client,
  }) : _client = client ?? http.Client();
  final String baseUrl;
  final Future<String?> Function(String userId) tokenProvider;
  final Future<void> Function(String userId)? onUnauthorized;
  final http.Client _client;
  @override
  bool get isDemo => false;
  @override
  bool get canSubmitReports => baseUrl.isNotEmpty;
  void dispose() => _client.close();

  Future<Never> _expired(String userId, String message) async {
    try {
      await onUnauthorized?.call(userId);
    } catch (_) {
      // A sign-out failure must not keep protected data visible.
    }
    throw DoctorWorkspaceAccessException(message);
  }

  Future<Map<String, dynamic>> _request(
    String userId,
    String path, {
    Map<String, dynamic>? body,
    String? requestId,
  }) async {
    final base = Uri.tryParse(baseUrl);
    if (base == null ||
        base.scheme != 'https' ||
        base.host.isEmpty ||
        base.userInfo.isNotEmpty ||
        base.hasQuery ||
        base.hasFragment) {
      throw StateError('Chưa cấu hình địa chỉ HTTPS của backend bác sĩ.');
    }
    final token = await tokenProvider(userId);
    if (token == null || token.isEmpty) {
      await _expired(
        userId,
        'Phiên đăng nhập không còn hợp lệ. Vui lòng đăng nhập lại.',
      );
    }
    final uri = Uri.parse('${baseUrl.replaceFirst(RegExp(r'/+$'), '')}/$path');
    final headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
      'Idempotency-Key': ?requestId,
    };
    final response =
        await (body == null
                ? _client.get(uri, headers: headers)
                : _client.post(uri, headers: headers, body: jsonEncode(body)))
            .timeout(const Duration(seconds: 20));
    if (response.statusCode == 401) {
      await _expired(
        userId,
        'Phiên đăng nhập hết hạn. Vui lòng đăng nhập lại.',
      );
    }
    if (response.statusCode == 403) {
      throw const DoctorWorkspaceAccessException(
        'Bạn không có quyền xem hoặc cập nhật dữ liệu này.',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Không thể kết nối dữ liệu bác sĩ. Vui lòng thử lại.');
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Phản hồi backend không hợp lệ.');
    }
    return decoded;
  }

  String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  List<Map<String, dynamic>> _list(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is! List || value.any((item) => item is! Map<String, dynamic>)) {
      throw FormatException('Thiếu dữ liệu $key.');
    }
    return value.cast<Map<String, dynamic>>();
  }

  @override
  Future<DoctorDayData> loadDay({
    required String userId,
    required DateTime date,
  }) async {
    final data = await _request(userId, 'doctor/day?date=${_date(date)}');
    if (data['doctor'] is! Map<String, dynamic>) {
      throw StateError('Chưa có hồ sơ bác sĩ được phân công.');
    }
    final doctor = DoctorModel.fromJson(data['doctor'] as Map<String, dynamic>);
    if (doctor.id.isEmpty ||
        doctor.userId != userId ||
        !doctor.isActive ||
        doctor.status.toUpperCase() != 'ACTIVE') {
      throw StateError(
        'Hồ sơ bác sĩ không hợp lệ hoặc không thuộc tài khoản đăng nhập.',
      );
    }
    final schedules = _list(
      data,
      'schedules',
    ).map(WorkScheduleModel.fromJson).toList();
    final slots = _list(data, 'slots').map(TimeSlotModel.fromJson).toList();
    final bookings = _list(data, 'bookings').map((row) {
      if (row['appointment'] is! Map<String, dynamic> ||
          row['patientName'] is! String) {
        throw const FormatException('Thông tin lịch khám không đầy đủ.');
      }
      return DoctorBooking(
        appointment: AppointmentModel.fromJson(
          row['appointment'] as Map<String, dynamic>,
        ),
        patientName: row['patientName'] as String,
        birthYear: row['birthYear'] as int?,
        gender: row['gender'] as String?,
      );
    }).toList();
    return DoctorDayData(
      doctor: doctor,
      date: date,
      schedules: schedules,
      slots: slots,
      bookings: bookings,
    );
  }

  DoctorReport _report(Map<String, dynamic> data) {
    final status = switch (data['status']) {
      'PENDING' => DoctorReportStatus.pending,
      'APPROVED' => DoctorReportStatus.approved,
      'REJECTED' => DoctorReportStatus.rejected,
      'RESOLVED' => DoctorReportStatus.resolved,
      _ => DoctorReportStatus.unknown,
    };
    return DoctorReport(
      id: data['id'] as String,
      type: data['type'] as String,
      date: DateTime.parse(data['date'] as String),
      reason: data['reason'] as String,
      status: status,
      adminResponse: data['adminResponse'] as String?,
    );
  }

  @override
  Future<List<DoctorReport>> loadReports({required String userId}) async =>
      _list(
        await _request(userId, 'doctor/reports'),
        'reports',
      ).map(_report).toList();
  @override
  Future<DoctorReport> submitReport({
    required String userId,
    required DoctorReportDraft draft,
  }) async => _report(
    await _request(
      userId,
      'doctor/reports',
      requestId: draft.requestId,
      body: {
        'type': draft.type,
        'scheduleId': draft.scheduleId,
        'date': _date(draft.date),
        'reason': draft.reason,
        'description': draft.description,
      },
    ),
  );
}
