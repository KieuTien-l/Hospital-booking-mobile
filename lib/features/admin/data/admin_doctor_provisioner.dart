import 'admin_commands.dart';

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

abstract interface class DoctorAccountProvisioner {
  Future<DoctorAccountProvisioningResult> provision(
    Map<String, dynamic> values, {
    required String requestId,
    required String reason,
  });
  Future<void> sendPasswordSetup(String email);
}

/// Auth creation, profiles, audit and receipt are owned by adminCommand.
/// A retry keeps the editor request ID, including after a lost acknowledgement.
/// The mobile client never creates/deletes a secondary Auth user.
class FirebaseDoctorAccountProvisioner implements DoctorAccountProvisioner {
  FirebaseDoctorAccountProvisioner({AdminCommands? commands})
    : _commands = commands ?? FirebaseAdminCommands();
  final AdminCommands _commands;

  @override
  Future<DoctorAccountProvisioningResult> provision(
    Map<String, dynamic> values, {
    required String requestId,
    required String reason,
  }) async {
    final result = await _commands.execute({
      'requestId': requestId,
      'operation': 'createDoctor',
      'collection': 'BAC_SI',
      'values': values,
      'reason': reason,
    });
    final doctorId = result['id'], email = result['loginEmail'];
    if (doctorId is! String ||
        doctorId.isEmpty ||
        email is! String ||
        email.isEmpty) {
      throw const AdminCommandException(
        'Chưa xác minh được kết quả tạo bác sĩ. Giữ nguyên biểu mẫu và thử lại.',
      );
    }
    var sent = true;
    try {
      await sendPasswordSetup(email);
    } catch (_) {
      sent = false;
    }
    return DoctorAccountProvisioningResult(
      doctorId: doctorId,
      loginEmail: email,
      passwordSetupSent: sent,
    );
  }

  @override
  Future<void> sendPasswordSetup(String email) =>
      _commands.sendPasswordSetup(email.trim());
}
