import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../doctors/data/models/doctor_model.dart';
import 'doctor_profile_page.dart';

/// Profile is read directly by the doctor's UID, independently of the scheduling API.
class ManagedDoctorProfilePage extends StatefulWidget {
  const ManagedDoctorProfilePage({
    super.key,
    this.doctor,
    this.isLoading = false,
    this.error,
    this.onRetry,
  });
  final Doctor? doctor;
  final bool isLoading;
  final String? error;
  final VoidCallback? onRetry;
  @override
  State<ManagedDoctorProfilePage> createState() =>
      _ManagedDoctorProfilePageState();
}

class _ManagedDoctorProfilePageState extends State<ManagedDoctorProfilePage> {
  String? _userId;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _stream;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final id = context.watch<AuthController>().currentUser?.id;
    if (id != _userId && Firebase.apps.isNotEmpty) {
      _userId = id;
      _listen();
    }
  }

  void _listen() {
    _stream = _userId == null
        ? null
        : FirebaseFirestore.instance
              .collection('BAC_SI')
              .where('userId', isEqualTo: _userId)
              .limit(2)
              .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    if (_stream == null) {
      return DoctorProfilePage(
        doctor: widget.doctor,
        isLoading: widget.isLoading,
        error: widget.error,
        onRetry: widget.onRetry,
      );
    }
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _stream,
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        final error = snapshot.hasError
            ? 'Chưa đọc được hồ sơ do admin cấp.'
            : docs.length > 1
            ? 'Tài khoản có nhiều hồ sơ bác sĩ liên kết; cần admin kiểm tra.'
            : snapshot.hasData && docs.isEmpty
            ? 'Chưa có hồ sơ bác sĩ được admin phân công.'
            : null;
        return DoctorProfilePage(
          doctor: !snapshot.hasError && docs.length == 1
              ? DoctorModel.fromFirestore(docs.single)
              : null,
          isLoading: !snapshot.hasData && !snapshot.hasError,
          error: error,
          onRetry: () => setState(_listen),
        );
      },
    );
  }
}
