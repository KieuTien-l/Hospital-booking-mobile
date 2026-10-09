import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/utils/model_value_parser.dart';
import '../../domain/entities/app_notification.dart';

class NotificationModel extends AppNotification {
  const NotificationModel({
    required super.id,
    required super.patientId,
    required super.title,
    required super.content,
    required super.createdAt,
    super.isRead = false,
  });

  factory NotificationModel.fromMap(Map<String, dynamic> map, String id) {
    return NotificationModel(
      id: id,
      patientId: readReferenceId(map['patientId']),
      title: readString(map['title']),
      content: readString(map['content']),
      createdAt: readDateTime(map['createdAt']) ?? DateTime.now(),
      isRead: readBool(map['isRead']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'patientId': patientId,
      'title': title,
      'content': content,
      'createdAt': Timestamp.fromDate(createdAt),
      'isRead': isRead,
    };
  }

  factory NotificationModel.fromEntity(AppNotification entity) {
    return NotificationModel(
      id: entity.id,
      patientId: entity.patientId,
      title: entity.title,
      content: entity.content,
      createdAt: entity.createdAt,
      isRead: entity.isRead,
    );
  }
}
