import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/feedback_ui_model.dart';
import 'customer_feedback_page.dart';

class LiveCustomerFeedbackPage extends StatefulWidget {
  const LiveCustomerFeedbackPage({super.key, required this.userId});
  final String userId;
  @override
  State<LiveCustomerFeedbackPage> createState() =>
      _LiveCustomerFeedbackPageState();
}

class _LiveCustomerFeedbackPageState extends State<LiveCustomerFeedbackPage> {
  // Patient profiles have one canonical document whose id is the Firebase
  // Auth UID. A broad `authUserId` query is both ambiguous for old duplicate
  // profiles and cannot be proven safe by the current Firestore Rules.
  late final _profile = FirebaseFirestore.instance
      .collection('BENH_NHAN')
      .doc(widget.userId)
      .get();
  String? _patient;
  String? _requestId;
  String? _lastBody;

  Future<void> _submit(FeedbackUiModel draft) async {
    if (_patient == null) {
      throw StateError('Vui lòng chọn hồ sơ bệnh nhân gửi phản hồi.');
    }
    final fields = {
      'patientId': _patient,
      'title': draft.title,
      'content': draft.content,
      'category': draft.category.name,
      'rating': draft.rating,
    };
    final body = jsonEncode(fields);
    if (_requestId == null || _lastBody != body) {
      _requestId = FirebaseFirestore.instance.collection('PHAN_HOI').doc().id;
    }
    _lastBody = body;
    final reference = FirebaseFirestore.instance
        .collection('PHAN_HOI')
        .doc(_requestId);
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final before = await tx.get(reference);
      if (before.exists) {
        if (!fields.entries.every((e) => before.data()?[e.key] == e.value)) {
          throw StateError('Mã yêu cầu đã dùng cho nội dung khác.');
        }
        return;
      }
      tx.set(reference, {...fields, 'createdAt': FieldValue.serverTimestamp()});
    });
    _requestId = null;
    _lastBody = null;
  }

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: _profile,
        builder: (context, profile) {
          if (!profile.hasData) {
            return Scaffold(
              appBar: AppBar(title: const Text('Phản hồi')),
              body: Center(
                child: profile.hasError
                    ? const Text(
                        'Chưa tải được hồ sơ bệnh nhân. Vui lòng quay lại và thử lại.',
                      )
                    : const CircularProgressIndicator(),
              ),
            );
          }
          final document = profile.data!;
          final records =
              document.exists &&
                  document.data()?['status'] != 'ARCHIVED' &&
                  document.data()?['isActive'] != false
              ? [document]
              : const <DocumentSnapshot<Map<String, dynamic>>>[];
          if (_patient == null && records.length == 1) {
            _patient = records.single.id;
          }
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            // Rules authorize feedback by the selected patient profile, not
            // by an arbitrary `userId` field.  This also makes the query work
            // for the canonical persisted feedback schema.
            stream: _patient == null
                ? null
                : FirebaseFirestore.instance
                      .collection('PHAN_HOI')
                      .where('patientId', isEqualTo: _patient)
                      .orderBy('createdAt', descending: true)
                      .limit(100)
                      .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Scaffold(
                  appBar: AppBar(title: const Text('Phản hồi')),
                  body: const Center(
                    child: Text(
                      'Chưa đọc được lịch sử phản hồi. Kiểm tra kết nối hoặc quyền truy cập.',
                    ),
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              final history = snapshot.data!.docs.map((doc) {
                final data = doc.data(), time = doc.data()['createdAt'];
                final date = time is Timestamp
                    ? time.toDate().toUtc().add(const Duration(hours: 7))
                    : null;
                return FeedbackUiModel(
                  title: '${data['title'] ?? ''}',
                  content: '${data['content'] ?? ''}',
                  category:
                      FeedbackCategory.values
                          .where((c) => c.name == data['category'])
                          .firstOrNull ??
                      FeedbackCategory.suggestion,
                  rating: data['rating'] is int ? data['rating'] as int : null,
                  dateLabel: date == null
                      ? 'Đang xác nhận thời gian'
                      : '${date.day}/${date.month}/${date.year}',
                  status: switch (data['processingStatus']) {
                    'PROCESSING' => FeedbackStatus.processing,
                    'RESOLVED' => FeedbackStatus.answered,
                    _ => FeedbackStatus.pending,
                  },
                  response: data['response'] as String?,
                );
              }).toList();
              return CustomerFeedbackPage(
                history: history,
                onSubmit: _submit,
                profileSelector: DropdownButtonFormField<String>(
                  initialValue: _patient,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Hồ sơ gửi phản hồi',
                  ),
                  items: [
                    for (final record in records)
                      DropdownMenuItem(
                        value: record.id,
                        child: Text(
                          '${record.data()?['fullName'] ?? record.id}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (v) => setState(() => _patient = v),
                  validator: (v) =>
                      v == null ? 'Chọn hồ sơ gửi phản hồi.' : null,
                ),
              );
            },
          );
        },
      );
}
