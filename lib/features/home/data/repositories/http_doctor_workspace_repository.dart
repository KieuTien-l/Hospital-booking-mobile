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
  @override
  bool get canWriteClinicalRecords => baseUrl.isNotEmpty;
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
    Map<String, dynamic>? decoded;
    try {
      final value = jsonDecode(utf8.decode(response.bodyBytes));
      if (value is Map<String, dynamic>) decoded = value;
    } catch (_) {
      // A non-JSON gateway response is handled by the generic error below.
    }
    if (response.statusCode == 401) {
      await _expired(
        userId,
        'Phiên đăng nhập hết hạn. Vui lòng đăng nhập lại.',
      );
    }
    if (response.statusCode == 403) {
      final error = decoded?['error'];
      if (error is Map &&
          error['message']?.toString().trim().isNotEmpty == true) {
        throw DoctorWorkspaceAccessException(error['message'].toString());
      }
      throw const DoctorWorkspaceAccessException(
        'Bạn không có quyền xem hoặc cập nhật dữ liệu này.',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = decoded?['error'];
      if (error is Map &&
          error['message']?.toString().trim().isNotEmpty == true) {
        throw StateError(error['message'].toString());
      }
      throw StateError('Không thể kết nối dữ liệu bác sĩ. Vui lòng thử lại.');
    }
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

  @override
  Future<void> updatePersonalProfile({
    required String userId,
    required DoctorPersonalProfileDraft draft,
  }) async {
    await _request(
      userId,
      'doctor/profile',
      body: {
        'fullName': draft.fullName,
        'email': draft.email,
        'phone': draft.phone,
        'dateOfBirth': _date(draft.dateOfBirth),
      },
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

  @override
  Future<DoctorAppointmentCompletion> completeAppointment({
    required String userId,
    required String appointmentId,
    required String requestId,
  }) async {
    final data = await _request(
      userId,
      'doctor/appointments/${Uri.encodeComponent(appointmentId)}/complete',
      requestId: requestId,
      body: const <String, dynamic>{},
    );
    final id = data['id']?.toString().trim() ?? '';
    final status = data['status']?.toString().trim() ?? '';
    final message = data['message']?.toString().trim() ?? '';
    if (id.isEmpty || status != 'COMPLETED' || message.isEmpty) {
      throw const FormatException('Phản hồi hoàn tất khám không hợp lệ.');
    }
    return DoctorAppointmentCompletion(
      id: id,
      status: status,
      message: message,
    );
  }

  @override
  Future<DoctorAppointmentCompletion> startExamination({
    required String userId,
    required String appointmentId,
    required String requestId,
  }) async {
    final data = await _request(
      userId,
      'doctor/examinations',
      requestId: requestId,
      body: {'appointmentId': appointmentId},
    );
    final id = data['id']?.toString().trim() ?? '';
    final status = data['status']?.toString().trim() ?? '';
    final message = data['message']?.toString().trim() ?? '';
    if (id.isEmpty || status != 'IN_PROGRESS' || message.isEmpty) {
      throw const FormatException('Phản hồi tạo phiếu khám không hợp lệ.');
    }
    return DoctorAppointmentCompletion(
      id: id,
      status: status,
      message: message,
    );
  }

  @override
  Future<DoctorAppointmentCompletion> markExaminationAwaitingResults({
    required String userId,
    required String appointmentId,
    required String requestId,
  }) async {
    final data = await _request(
      userId,
      'doctor/examinations/${Uri.encodeComponent(appointmentId)}/awaiting-results',
      requestId: requestId,
      body: const <String, dynamic>{},
    );
    final id = data['id']?.toString().trim() ?? '';
    final status = data['status']?.toString().trim() ?? '';
    final message = data['message']?.toString().trim() ?? '';
    if (id.isEmpty || status != 'WAITING_RESULTS' || message.isEmpty) {
      throw const FormatException('Phản hồi chờ kết quả CLS không hợp lệ.');
    }
    return DoctorAppointmentCompletion(
      id: id,
      status: status,
      message: message,
    );
  }

  DoctorClinicalSaveResult _clinicalResult(Map<String, dynamic> data) {
    final id = data['id']?.toString().trim() ?? '';
    final message = data['message']?.toString().trim() ?? '';
    if (id.isEmpty || message.isEmpty) {
      throw const FormatException('Phản hồi lưu hồ sơ không hợp lệ.');
    }
    return DoctorClinicalSaveResult(id: id, message: message);
  }

  @override
  Future<DoctorClinicalSaveResult> saveHealthRecord({
    required String userId,
    required DoctorHealthRecordDraft draft,
  }) async => _clinicalResult(
    await _request(
      userId,
      'doctor/health-records',
      requestId: draft.requestId,
      body: {
        if (draft.id?.isNotEmpty ?? false) 'id': draft.id,
        'appointmentId': draft.appointmentId,
        'diagnosis': draft.diagnosis,
        'notes': draft.notes,
        'prescription': draft.prescription,
        'recordType': draft.recordType,
      },
    ),
  );

  @override
  Future<DoctorClinicalSaveResult> createClinicalOrder({
    required String userId,
    required DoctorClinicalOrderDraft draft,
  }) async => _clinicalResult(
    await _request(
      userId,
      'doctor/clinical-orders',
      requestId: draft.requestId,
      body: {
        'appointmentId': draft.appointmentId,
        'testName': draft.testName,
        'resultType': draft.resultType,
        'notes': draft.notes,
      },
    ),
  );

  @override
  Future<List<DoctorClinicalOrderSummary>> loadClinicalOrders({
    required String userId,
    required String appointmentId,
  }) async =>
      _list(
            await _request(
              userId,
              'doctor/clinical-orders?appointmentId=$appointmentId',
            ),
            'orders',
          )
          .map(
            (item) => DoctorClinicalOrderSummary(
              id: item['id'] as String,
              testName: item['testName'] as String,
              resultType: item['resultType'] as String,
              status: item['status'] as String,
              notes: item['notes'] as String,
            ),
          )
          .toList(growable: false);

  @override
  Future<DoctorClinicalSaveResult> saveTestResult({
    required String userId,
    required DoctorTestResultDraft draft,
  }) async => _clinicalResult(
    await _request(
      userId,
      'doctor/test-results',
      requestId: draft.requestId,
      body: {
        if (draft.id?.isNotEmpty ?? false) 'id': draft.id,
        'appointmentId': draft.appointmentId,
        'orderId': draft.orderId,
        'testName': draft.testName,
        'resultDescription': draft.resultDescription,
        'resultType': draft.resultType,
        'conclusion': draft.conclusion,
        'referenceRange': draft.referenceRange,
      },
    ),
  );

  @override
  Future<List<DoctorHealthRecordSummary>> loadHealthRecords({
    required String userId,
    required String appointmentId,
  }) async =>
      _list(
            await _request(
              userId,
              'doctor/health-records?appointmentId=$appointmentId',
            ),
            'records',
          )
          .map(
            (item) => DoctorHealthRecordSummary(
              id: item['id'] as String,
              diagnosis: item['diagnosis'] as String,
              notes: item['notes'] as String,
              prescription: item['prescription'] as String,
              recordType: item['recordType'] as String,
            ),
          )
          .toList(growable: false);

  @override
  Future<List<DoctorTestResultSummary>> loadTestResults({
    required String userId,
    required String appointmentId,
  }) async =>
      _list(
            await _request(
              userId,
              'doctor/test-results?appointmentId=$appointmentId',
            ),
            'records',
          )
          .map(
            (item) => DoctorTestResultSummary(
              id: item['id'] as String,
              testName: item['testName'] as String,
              resultDescription: item['resultDescription'] as String,
              resultType: item['resultType'] as String,
              conclusion: item['conclusion'] as String,
              referenceRange: item['referenceRange'] as String,
              orderId: item['orderId'] as String?,
            ),
          )
          .toList(growable: false);

  @override
  Future<DoctorPatientHistory> loadPatientHistory({
    required String userId,
    required String patientId,
  }) async {
    final data = await _request(
      userId,
      'doctor/patients/${Uri.encodeComponent(patientId)}/history',
    );
    final visits = _list(data, 'visits')
        .map(
          (item) => DoctorPatientVisit(
            id: item['id'] as String,
            date: DateTime.parse(item['date'] as String),
            status: item['status'] as String,
          ),
        )
        .toList(growable: false);
    final healthRecords = _list(data, 'healthRecords')
        .map(
          (item) => DoctorHealthRecordSummary(
            id: item['id'] as String,
            diagnosis: item['diagnosis'] as String,
            notes: item['notes'] as String,
            prescription: item['prescription'] as String,
            recordType: item['recordType'] as String,
          ),
        )
        .toList(growable: false);
    final testResults = _list(data, 'testResults')
        .map(
          (item) => DoctorTestResultSummary(
            id: item['id'] as String,
            testName: item['testName'] as String,
            resultDescription: item['resultDescription'] as String,
            resultType: item['resultType'] as String,
            conclusion: item['conclusion'] as String,
            referenceRange: item['referenceRange'] as String,
          ),
        )
        .toList(growable: false);
    return DoctorPatientHistory(
      patientId: data['patientId'] as String,
      visits: visits,
      healthRecords: healthRecords,
      testResults: testResults,
    );
  }
}
