import 'dart:convert';

import 'package:http/http.dart' as http;

/// A province or ward returned by the public Vietnam administrative catalogue.
class VietnamAdministrativeDivision {
  const VietnamAdministrativeDivision({required this.code, required this.name});

  final int code;
  final String name;

  factory VietnamAdministrativeDivision.fromJson(Map<String, dynamic> json) {
    final code = json['code'];
    final name = json['name'];
    if (code is! num || name is! String || name.trim().isEmpty) {
      throw const FormatException('Dữ liệu đơn vị hành chính không hợp lệ.');
    }
    return VietnamAdministrativeDivision(code: code.toInt(), name: name.trim());
  }
}

/// Reads the post-2025 Vietnam province/ward catalogue on demand.
///
/// Loading wards only after a province has been selected avoids downloading a
/// nationwide ward list into the mobile app.
class VietnamAdministrativeDivisionService {
  VietnamAdministrativeDivisionService({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;
  static const _host = 'provinces.open-api.vn';

  Future<List<VietnamAdministrativeDivision>> provinces() =>
      _load('/api/v2/p/');

  Future<List<VietnamAdministrativeDivision>> wards(int provinceCode) =>
      _load('/api/v2/w/', query: {'province': '$provinceCode'});

  Future<List<VietnamAdministrativeDivision>> _load(
    String path, {
    Map<String, String>? query,
  }) async {
    final response = await _client
        .get(Uri.https(_host, path, query))
        .timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      throw const FormatException('Chưa tải được danh mục địa chỉ.');
    }
    final payload = jsonDecode(response.body);
    final values = payload is List
        ? payload
        : payload is Map<String, dynamic> && payload['data'] is List
        ? payload['data'] as List<dynamic>
        : null;
    if (values == null) {
      throw const FormatException('Chưa tải được danh mục địa chỉ.');
    }
    final divisions =
        values
            .whereType<Map>()
            .map(
              (value) => VietnamAdministrativeDivision.fromJson(
                Map<String, dynamic>.from(value),
              ),
            )
            .toList()
          ..sort((left, right) => left.name.compareTo(right.name));
    return List.unmodifiable(divisions);
  }
}
