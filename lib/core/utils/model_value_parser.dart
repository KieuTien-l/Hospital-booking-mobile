import 'package:cloud_firestore/cloud_firestore.dart';

String readString(Object? value, {String fallback = ''}) {
  return value?.toString().trim() ?? fallback;
}

String? readOptionalString(Object? value) {
  final result = readString(value);
  return result.isEmpty ? null : result;
}

Object? readFirstValue(Map<String, dynamic> values, Iterable<String> keys) {
  for (final key in keys) {
    final value = values[key];
    if (value != null) return value;
  }
  return null;
}

String readStringForKeys(
  Map<String, dynamic> values,
  Iterable<String> keys, {
  String fallback = '',
}) {
  return readString(readFirstValue(values, keys), fallback: fallback);
}

String? readOptionalStringForKeys(
  Map<String, dynamic> values,
  Iterable<String> keys,
) {
  final value = readStringForKeys(values, keys);
  return value.isEmpty ? null : value;
}

String? readTimeString(Object? value) {
  if (value is Timestamp) return value.toDate().toIso8601String();
  if (value is DateTime) return value.toIso8601String();
  final result = readString(value);
  return result.isEmpty ? null : result;
}

String? readTimeStringForKeys(
  Map<String, dynamic> values,
  Iterable<String> keys,
) {
  return readTimeString(readFirstValue(values, keys));
}

String readReferenceId(Object? value, {String fallback = ''}) {
  if (value is DocumentReference) return value.id;
  if (value is Map) {
    for (final key in const ['id', 'Id', 'ID', 'documentId', 'DocumentId']) {
      final nestedValue = value[key];
      if (nestedValue != null) {
        return readReferenceId(nestedValue, fallback: fallback);
      }
    }
  }
  return readString(value, fallback: fallback);
}

String readReferenceIdForKeys(
  Map<String, dynamic> values,
  Iterable<String> keys, {
  String fallback = '',
}) {
  return readReferenceId(readFirstValue(values, keys), fallback: fallback);
}

bool readBool(Object? value, {bool fallback = false}) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    return value.toLowerCase() == 'true' || value == '1';
  }
  return fallback;
}

int readInt(Object? value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

double readDouble(Object? value, {double fallback = 0}) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? fallback;
}

DateTime? readDateTime(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is num) {
    return DateTime.fromMillisecondsSinceEpoch(value.toInt());
  }
  if (value is String) return DateTime.tryParse(value);
  return null;
}
