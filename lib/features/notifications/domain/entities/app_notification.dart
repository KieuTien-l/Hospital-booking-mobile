import 'package:cloud_firestore/cloud_firestore.dart';

class AppNotification {
  final String id;
  final String patientId;
  final String title;
  final String content;
  final DateTime createdAt;
  final bool isRead;

  const AppNotification({
    required this.id,
    required this.patientId,
    required this.title,
    required this.content,
    required this.createdAt,
    this.isRead = false,
  });

  AppNotification copyWith({
    String? id,
    String? patientId,
    String? title,
    String? content,
    DateTime? createdAt,
    bool? isRead,
  }) {
    return AppNotification(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
    );
  }
}
