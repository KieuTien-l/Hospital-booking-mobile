import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../../firebase_options.dart';
import 'admin_commands.dart';

/// Result after an administrator provisions a doctor account from the app.
class DoctorAccountProvisioningResult {
  const DoctorAccountProvisioningResult({
    required this.doctorId,
    required this.loginEmail,
    required this.passwordSetupSent,
  });

  final String doctorId;
  final String loginEmail;
  final bool passwordSetupSent;

  String get message => passwordSetupSent
      ? 'Đã tạo hồ sơ bác sĩ và gửi email thiết lập mật khẩu.'
      : 'Đã tạo hồ sơ bác sĩ, nhưng chưa gửi được email thiết lập mật khẩu. Hãy gửi lại từ hồ sơ bác sĩ.';
}

/// This interface has no role input: the screen can only provision doctors.
abstract interface class DoctorAccountProvisioner {
  Future<DoctorAccountProvisioningResult> provision(
    Map<String, dynamic> values,
  );

  Future<void> sendPasswordSetup(String email);
}

/// Creates the new user with a secondary Auth app, keeping the primary admin
/// session intact. The primary admin session then writes the two Firestore
/// profiles in one transaction under the Firestore Rules' admin permission.
class FirebaseDoctorAccountProvisioner implements DoctorAccountProvisioner {
  FirebaseDoctorAccountProvisioner({
    FirebaseAuth? primaryAuth,
    FirebaseFirestore? firestore,
    FirebaseOptions? options,
  }) : _primaryAuth = primaryAuth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _options = options ?? DefaultFirebaseOptions.currentPlatform;

  final FirebaseAuth _primaryAuth;
  final FirebaseFirestore _firestore;
  final FirebaseOptions _options;

  @override
  Future<DoctorAccountProvisioningResult> provision(
    Map<String, dynamic> input,
  ) async {
    if (_primaryAuth.currentUser == null) {
      throw const AdminCommandException(
        'Phiên quản trị đã hết hạn. Vui lòng đăng nhập lại.',
      );
    }
    final loginEmail = _email(input['loginEmail'], 'Email đăng nhập');
    final fullName = _requiredText(input['fullName'], 'Họ và tên');
    final specialtyId = _requiredText(input['specialtyId'], 'Chuyên khoa');
    final phone = _text(input['phone']);
    final contactEmail = _text(input['email']).isEmpty
        ? loginEmail
        : _email(input['email'], 'Email liên hệ');
    final yearsOfExperience = _nonNegativeInt(
      input['yearsOfExperience'],
      'Số năm kinh nghiệm',
    );
    final consultationFee = _nonNegativeNumber(
      input['consultationFee'],
      'Phí khám',
    );

    final appName =
        'doctor-provision-${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';
    final secondaryApp = await Firebase.initializeApp(
      name: appName,
      options: _options,
    );
    final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
    User? doctorUser;
    var committed = false;
    try {
      final credential = await secondaryAuth.createUserWithEmailAndPassword(
        email: loginEmail,
        password: _temporaryPassword(),
      );
      doctorUser = credential.user;
      if (doctorUser == null) {
        throw const AdminCommandException('Không thể tạo tài khoản đăng nhập.');
      }
      final doctorId = doctorUser.uid;

      await _firestore.runTransaction((transaction) async {
        final specialty = await transaction.get(
          _firestore.collection('CHUYEN_KHOA').doc(specialtyId),
        );
        if (!specialty.exists || !_isActive(specialty.data())) {
          throw const AdminCommandException(
            'Chuyên khoa không tồn tại hoặc đã ngừng hoạt động.',
          );
        }
        transaction.set(_firestore.collection('TAI_KHOAN').doc(doctorId), {
          'email': loginEmail,
          'fullName': fullName,
          'phone': phone,
          'role': 'doctor',
          'isActive': true,
          'status': 'ACTIVE',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        transaction.set(_firestore.collection('BAC_SI').doc(doctorId), {
          'userId': doctorId,
          'fullName': fullName,
          'email': contactEmail,
          'phone': phone,
          'specialtyId': specialtyId,
          'yearsOfExperience': yearsOfExperience,
          'consultationFee': consultationFee,
          'isActive': true,
          'status': 'ACTIVE',
          'acceptingBookings': true,
          if (_date(input['dateOfBirth']) != null)
            'dateOfBirth': Timestamp.fromDate(_date(input['dateOfBirth'])!),
          if (_text(input['gender']).isNotEmpty)
            'gender': _text(input['gender']),
          if (_text(input['address']).isNotEmpty)
            'address': _text(input['address']),
          if (_text(input['qualification']).isNotEmpty)
            'qualification': _text(input['qualification']),
          if (_text(input['biography']).isNotEmpty)
            'biography': _text(input['biography']),
          if (_text(input['avatarUrl']).isNotEmpty)
            'avatarUrl': _text(input['avatarUrl']),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
      committed = true;

      var passwordSetupSent = true;
      try {
        await sendPasswordSetup(loginEmail);
      } on AdminCommandException {
        passwordSetupSent = false;
      }
      return DoctorAccountProvisioningResult(
        doctorId: doctorId,
        loginEmail: loginEmail,
        passwordSetupSent: passwordSetupSent,
      );
    } on FirebaseAuthException catch (error) {
      throw AdminCommandException(_authMessage(error));
    } on AdminCommandException {
      rethrow;
    } on FirebaseException catch (error) {
      throw AdminCommandException(_firestoreMessage(error));
    } catch (_) {
      throw const AdminCommandException(
        'Không thể tạo hồ sơ bác sĩ. Vui lòng kiểm tra kết nối và thử lại.',
      );
    } finally {
      if (!committed && doctorUser != null) {
        try {
          await doctorUser.delete();
        } catch (_) {
          // The incomplete Auth record must be removed manually only if this
          // best-effort cleanup also fails.
        }
      }
      await secondaryApp.delete();
    }
  }

  @override
  Future<void> sendPasswordSetup(String email) async {
    try {
      await _primaryAuth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (error) {
      throw AdminCommandException(_passwordResetMessage(error));
    } catch (_) {
      throw const AdminCommandException(
        'Không thể gửi email thiết lập mật khẩu. Vui lòng thử lại.',
      );
    }
  }

  String _requiredText(Object? value, String label) {
    final result = _text(value);
    if (result.isEmpty) throw AdminCommandException('$label là bắt buộc.');
    return result;
  }

  String _email(Object? value, String label) {
    final result = _requiredText(value, label).toLowerCase();
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(result)) {
      throw AdminCommandException('$label không hợp lệ.');
    }
    return result;
  }

  String _text(Object? value) => value?.toString().trim() ?? '';

  int _nonNegativeInt(Object? value, String label) {
    final number = value is num ? value : num.tryParse(_text(value));
    if (number == null || number < 0 || number != number.roundToDouble()) {
      throw AdminCommandException('$label phải là số nguyên không âm.');
    }
    return number.toInt();
  }

  double _nonNegativeNumber(Object? value, String label) {
    final number = value is num
        ? value.toDouble()
        : double.tryParse(_text(value));
    if (number == null || !number.isFinite || number < 0) {
      throw AdminCommandException('$label phải là số không âm.');
    }
    return number;
  }

  DateTime? _date(Object? value) => DateTime.tryParse(_text(value));

  bool _isActive(Map<String, dynamic>? data) {
    if (data == null || data['isActive'] == false) return false;
    return _text(data['status']).toUpperCase() != 'INACTIVE';
  }

  String _temporaryPassword() {
    const alphabet =
        'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#%';
    final random = Random.secure();
    return List.generate(
      32,
      (_) => alphabet[random.nextInt(alphabet.length)],
    ).join();
  }

  String _authMessage(FirebaseAuthException error) => switch (error.code) {
    'email-already-in-use' => 'Email đăng nhập này đã được sử dụng.',
    'invalid-email' => 'Email đăng nhập không hợp lệ.',
    'network-request-failed' =>
      'Không thể kết nối Firebase Authentication. Vui lòng kiểm tra mạng.',
    _ => 'Không thể tạo tài khoản đăng nhập bác sĩ. Vui lòng thử lại.',
  };

  String _firestoreMessage(FirebaseException error) => switch (error.code) {
    'permission-denied' => 'Bạn không có quyền tạo hồ sơ bác sĩ.',
    'unavailable' => 'Không thể kết nối Firestore. Vui lòng kiểm tra mạng.',
    _ => 'Không thể lưu hồ sơ bác sĩ. Vui lòng thử lại.',
  };

  String _passwordResetMessage(FirebaseAuthException error) =>
      switch (error.code) {
        'too-many-requests' =>
          'Đã gửi email quá nhiều lần. Vui lòng chờ rồi thử lại.',
        'network-request-failed' => 'Không thể gửi email do lỗi kết nối mạng.',
        _ => 'Không thể gửi email thiết lập mật khẩu. Vui lòng thử lại.',
      };
}
