import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../../../core/models/user_model.dart';
import '../../../../core/network/api_exception.dart';

class AuthFirestoreRestDatasource {
  AuthFirestoreRestDatasource({
    http.Client? client,
    this.projectId = 'bookinghospitalapp',
    this.timeout = const Duration(seconds: 10),
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final String projectId;
  final Duration timeout;

  Future<UserModel> getUser({
    required String userId,
    required String idToken,
  }) async {
    final uri = Uri.https(
      'firestore.googleapis.com',
      '/v1/projects/$projectId/databases/(default)/documents/TAI_KHOAN/$userId',
    );

    try {
      final response = await _client
          .get(
            uri,
            headers: {
              'Authorization': 'Bearer $idToken',
              'Accept': 'application/json',
            },
          )
          .timeout(timeout);

      if (response.statusCode != 200) {
        throw ApiException(
          kind: ApiFailureKind.http,
          message: _httpErrorMessage(response.statusCode),
          statusCode: response.statusCode,
        );
      }

      return _deserializeUser(response.body, userId);
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw const ApiException(
        kind: ApiFailureKind.timeout,
        message: 'The request timed out. Please try again.',
      );
    } on SocketException {
      throw const ApiException(
        kind: ApiFailureKind.network,
        message: 'No network connection. Check your connection and try again.',
      );
    } on http.ClientException {
      throw const ApiException(
        kind: ApiFailureKind.network,
        message: 'No network connection. Check your connection and try again.',
      );
    } on FormatException {
      throw const ApiException(
        kind: ApiFailureKind.invalidResponse,
        message: 'The server returned an invalid account profile.',
      );
    } on TypeError {
      throw const ApiException(
        kind: ApiFailureKind.invalidResponse,
        message: 'The server returned an invalid account profile.',
      );
    }
  }

  UserModel _deserializeUser(String responseBody, String userId) {
    final decoded = jsonDecode(responseBody);
    if (decoded is! Map) {
      throw const FormatException('Firestore document must be a JSON object.');
    }

    final fields = decoded['fields'];
    if (fields is! Map) {
      throw const FormatException('Firestore document has no fields.');
    }

    final profile = <String, dynamic>{};
    for (final name in _profileFieldNames) {
      final rawValue = fields[name];
      if (rawValue != null) {
        profile[name] = _readFirestoreValue(rawValue);
      }
    }

    final email = profile['email'];
    if (email is! String || email.trim().isEmpty) {
      throw const FormatException('Firestore profile is missing an email.');
    }

    return UserModel.fromJson(profile, documentId: userId);
  }

  Object? _readFirestoreValue(Object? rawValue) {
    if (rawValue is! Map) {
      throw const FormatException('Firestore field has an invalid value.');
    }

    for (final type in _supportedValueTypes) {
      if (rawValue.containsKey(type)) {
        return rawValue[type];
      }
    }
    throw const FormatException('Firestore field type is not supported.');
  }

  String _httpErrorMessage(int statusCode) {
    switch (statusCode) {
      case 401:
      case 403:
        return 'Your session has expired. Please sign in again.';
      case 404:
        return 'Account profile was not found.';
      default:
        return 'Unable to load the account profile (HTTP $statusCode).';
    }
  }
}

const _profileFieldNames = <String>{
  'department',
  'accountKey',
  'permission',
  'status',
  'email',
  'fullName',
  'phone',
  'role',
  'isActive',
  'createdAt',
  'updatedAt',
};

const _supportedValueTypes = <String>{
  'stringValue',
  'booleanValue',
  'integerValue',
  'doubleValue',
  'timestampValue',
  'nullValue',
};
