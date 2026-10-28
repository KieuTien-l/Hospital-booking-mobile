import 'dart:convert';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

String adminRequestId() {
  final random = Random.secure();
  return List.generate(
    24,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}

class AdminCommandException implements Exception {
  const AdminCommandException(this.message);
  final String message;
  @override
  String toString() => message;
}

abstract interface class AdminCommands {
  Future<Map<String, dynamic>> execute(Map<String, dynamic> command);
  Future<void> sendPasswordSetup(String email);
}

/// Callable protocol over the existing HTTP dependency. Auth remains on the
/// primary app; only the trusted server creates doctor Auth users.
class FirebaseAdminCommands implements AdminCommands {
  FirebaseAdminCommands({
    http.Client? client,
    Future<String?> Function()? tokenProvider,
    this.endpointOverride,
    Future<void> Function(String)? passwordSender,
  }) : _client = client ?? http.Client(),
       _tokenProvider =
           tokenProvider ??
           (() =>
               FirebaseAuth.instance.currentUser?.getIdToken(true) ??
               Future.value(null)),
       _passwordSender =
           passwordSender ??
           ((email) =>
               FirebaseAuth.instance.sendPasswordResetEmail(email: email));

  final http.Client _client;
  final Future<String?> Function() _tokenProvider;
  final Uri? endpointOverride;
  final Future<void> Function(String) _passwordSender;
  void dispose() => _client.close();

  Uri get endpoint {
    if (endpointOverride != null) return endpointOverride!;
    const workerUrl = String.fromEnvironment('ADMIN_COMMAND_BASE_URL');
    if (workerUrl.isNotEmpty) {
      final uri = Uri.tryParse(workerUrl);
      if (uri == null ||
          !uri.isAbsolute ||
          uri.scheme != 'https' ||
          uri.userInfo.isNotEmpty ||
          uri.hasQuery ||
          uri.hasFragment) {
        throw const AdminCommandException(
          'ADMIN_COMMAND_BASE_URL phải là URL HTTPS hợp lệ, không kèm thông tin đăng nhập hoặc query.',
        );
      }
      return uri;
    }
    final project = Firebase.app().options.projectId;
    const emulator = String.fromEnvironment('ADMIN_EMULATOR_HOST');
    if (emulator.isNotEmpty) {
      final uri = Uri.parse('http://$emulator');
      if (!kDebugMode ||
          !{'localhost', '127.0.0.1', '10.0.2.2'}.contains(uri.host) ||
          uri.userInfo.isNotEmpty ||
          uri.path.isNotEmpty ||
          uri.hasQuery ||
          uri.hasFragment) {
        throw const AdminCommandException(
          'Cấu hình emulator admin không hợp lệ.',
        );
      }
      return uri.replace(path: '/$project/asia-southeast1/adminCommand');
    }
    return Uri.https(
      'asia-southeast1-$project.cloudfunctions.net',
      '/adminCommand',
    );
  }

  @override
  Future<Map<String, dynamic>> execute(Map<String, dynamic> command) async {
    final token = await _tokenProvider();
    if (token == null || token.isEmpty) {
      throw const AdminCommandException(
        'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
      );
    }
    try {
      final response = await _client
          .post(
            endpoint,
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(_usesWorkerEndpoint ? command : {'data': command}),
          )
          .timeout(const Duration(seconds: 70));
      if (response.statusCode == 404) {
        throw const AdminCommandException(
          'Không tìm thấy backend Admin. Nếu dùng Cloudflare Worker, hãy chạy/build app với ADMIN_COMMAND_BASE_URL; nếu dùng Firebase Functions, hãy triển khai adminCommand.',
        );
      }
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) throw const FormatException();
      if (decoded['error'] is Map) {
        final error = decoded['error'] as Map;
        throw AdminCommandException(
          error['message']?.toString() ?? 'Không thể hoàn tất thao tác.',
        );
      }
      final result = decoded['result'] ?? decoded['data'];
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          result is! Map<String, dynamic>) {
        throw const FormatException();
      }
      return result;
    } on AdminCommandException {
      rethrow;
    } catch (_) {
      throw const AdminCommandException(
        'Chưa xác minh được kết quả. Giữ nguyên biểu mẫu và bấm lưu lại để thử cùng mã yêu cầu, tránh tạo trùng.',
      );
    }
  }

  bool get _usesWorkerEndpoint =>
      endpointOverride == null &&
      const String.fromEnvironment('ADMIN_COMMAND_BASE_URL').isNotEmpty;

  @override
  Future<void> sendPasswordSetup(String email) async {
    try {
      await _passwordSender(email);
    } catch (_) {
      throw const AdminCommandException(
        'Chưa gửi được email thiết lập mật khẩu. Tài khoản vẫn được giữ; có thể gửi lại từ chi tiết bác sĩ/tài khoản.',
      );
    }
  }
}
