import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../../admin/data/admin_commands.dart';

class PayosPaymentException implements Exception {
  const PayosPaymentException(this.message);

  final String message;

  @override
  String toString() => message;
}

class PayosPaymentSession {
  const PayosPaymentSession({
    required this.id,
    required this.appointmentId,
    required this.amount,
    required this.status,
    this.checkoutUrl,
    this.qrCode,
    this.transactionCode,
  });

  final String id;
  final String appointmentId;
  final int amount;
  final String status;
  final String? checkoutUrl;
  final String? qrCode;
  final String? transactionCode;

  bool get isPaid => status.trim().toUpperCase() == 'PAID';
  bool get isPending =>
      const {'CREATING', 'PENDING'}.contains(status.trim().toUpperCase());
  bool get canCancel => const {
    'CREATING',
    'PENDING',
    'CREATE_FAILED',
  }.contains(status.trim().toUpperCase());

  factory PayosPaymentSession.fromJson(Map<String, dynamic> json) {
    final amount = json['amount'];
    return PayosPaymentSession(
      id: json['id']?.toString() ?? '',
      appointmentId: json['appointmentId']?.toString() ?? '',
      amount: amount is num ? amount.toInt() : 0,
      status: json['status']?.toString() ?? 'PENDING',
      checkoutUrl: _optional(json['checkoutUrl']),
      qrCode: _optional(json['qrCode']),
      transactionCode: _optional(json['transactionCode']),
    );
  }

  static String? _optional(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }
}

/// Narrow client for the patient-facing PayOS endpoints. It deliberately
/// never receives PayOS credentials; it only carries the Firebase ID token.
class PayosPaymentClient {
  PayosPaymentClient({
    http.Client? client,
    Future<String?> Function()? tokenProvider,
    Uri? baseUrl,
  }) : _client = client ?? http.Client(),
       _tokenProvider =
           tokenProvider ??
           (() =>
               FirebaseAuth.instance.currentUser?.getIdToken(true) ??
               Future.value(null)),
       _baseUrl = baseUrl ?? _configuredBaseUrl();

  final http.Client _client;
  final Future<String?> Function() _tokenProvider;
  final Uri _baseUrl;

  void dispose() => _client.close();

  static Uri _configuredBaseUrl() {
    const explicit = String.fromEnvironment('PAYMENT_WORKER_BASE_URL');
    const adminCommand = String.fromEnvironment('ADMIN_COMMAND_BASE_URL');
    final source = explicit.isNotEmpty ? explicit : adminCommand;
    final uri = Uri.tryParse(source);
    if (uri == null ||
        !uri.isAbsolute ||
        uri.scheme != 'https' ||
        uri.userInfo.isNotEmpty) {
      throw const PayosPaymentException(
        'Dịch vụ thanh toán chưa được cấu hình. Hãy chạy app với ADMIN_COMMAND_BASE_URL hoặc PAYMENT_WORKER_BASE_URL.',
      );
    }
    return uri.replace(path: '', query: null, fragment: null);
  }

  Future<PayosPaymentSession> create({required String appointmentId}) =>
      _request(
        'POST',
        '/payments/create',
        body: {
          'appointmentId': appointmentId.trim(),
          'requestId': adminRequestId(),
        },
      );

  Future<PayosPaymentSession> status(String paymentId) =>
      _request('GET', '/payments/${Uri.encodeComponent(paymentId.trim())}');

  Future<PayosPaymentSession> cancel(
    String paymentId, {
    String reason = 'Bệnh nhân hủy thanh toán trong ứng dụng.',
  }) => _request(
    'POST',
    '/payments/${Uri.encodeComponent(paymentId.trim())}/cancel',
    body: {'reason': reason},
  );

  Future<PayosPaymentSession> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final token = await _tokenProvider();
    if (token == null || token.isEmpty) {
      throw const PayosPaymentException('Phiên đăng nhập đã hết hạn.');
    }
    final target = _baseUrl.replace(path: path);
    try {
      final Future<http.Response> responseFuture = switch (method) {
        'GET' => _client.get(
          target,
          headers: {'Authorization': 'Bearer $token'},
        ),
        _ => _client.post(
          target,
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(body ?? const <String, dynamic>{}),
        ),
      };
      final response = await responseFuture.timeout(
        const Duration(seconds: 45),
      );
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) throw const FormatException();
      final error = decoded['error'];
      if (error is Map) {
        throw PayosPaymentException(
          error['message']?.toString() ?? 'Không thể xử lý thanh toán.',
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw const FormatException();
      }
      return PayosPaymentSession.fromJson(decoded);
    } on PayosPaymentException {
      rethrow;
    } catch (_) {
      throw const PayosPaymentException(
        'Không thể kết nối dịch vụ thanh toán. Vui lòng kiểm tra mạng và thử lại.',
      );
    }
  }
}
