import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_4/features/admin/data/admin_commands.dart';
import 'package:flutter_application_4/features/admin/data/admin_doctor_provisioner.dart';

class _Commands implements AdminCommands {
  final calls = <Map<String, dynamic>>[];
  final emails = <String>[];
  bool loseFirstAck = false;
  bool failEmail = false;
  @override
  Future<Map<String, dynamic>> execute(Map<String, dynamic> command) async {
    calls.add(command);
    if (loseFirstAck && calls.length == 1) {
      throw const AdminCommandException('Lost acknowledgement');
    }
    return {'id': 'doctor-uid', 'loginEmail': 'doctor@example.com'};
  }

  @override
  Future<void> sendPasswordSetup(String email) async {
    emails.add(email);
    if (failEmail) throw const AdminCommandException('offline');
  }
}

void main() {
  const values = {'fullName': 'Bác sĩ mới', 'loginEmail': 'doctor@example.com'};
  test('ADM-20: production provisioner uses audited server command with editor request ID', () async {
    final commands = _Commands();
    final provisioner = FirebaseDoctorAccountProvisioner(commands: commands);
    final result = await provisioner.provision(
      values,
      requestId: 'editor-id',
      reason: 'Tuyển bác sĩ',
    );
    expect(commands.calls.single['operation'], 'createDoctor');
    expect(commands.calls.single['requestId'], 'editor-id');
    expect(commands.calls.single['reason'], 'Tuyển bác sĩ');
    expect(commands.calls.single['values'], values);
    expect(result.doctorId, 'doctor-uid');
    expect(commands.emails, ['doctor@example.com']);
    expect(result.passwordSetupSent, isTrue);
  });
  test(
    'ADM-20: acknowledgement loss keeps the same request ID on retry',
    () async {
      final commands = _Commands()..loseFirstAck = true;
      final provisioner = FirebaseDoctorAccountProvisioner(commands: commands);
      await expectLater(
        provisioner.provision(
          values,
          requestId: 'same-id',
          reason: 'Tuyển bác sĩ',
        ),
        throwsA(isA<AdminCommandException>()),
      );
      final result = await provisioner.provision(
        values,
        requestId: 'same-id',
        reason: 'Tuyển bác sĩ',
      );
      expect(commands.calls.map((c) => c['requestId']), ['same-id', 'same-id']);
      expect(commands.emails, hasLength(1));
      expect(result.doctorId, 'doctor-uid');
    },
  );
  test('ADM-20: failed invitation preserves provisioned identity and reports the email failure', () async {
    final commands = _Commands()..failEmail = true;
    final result = await FirebaseDoctorAccountProvisioner(commands: commands)
        .provision(values, requestId: 'invite-id', reason: 'Tuyển bác sĩ');
    expect(result.doctorId, 'doctor-uid');
    expect(result.passwordSetupSent, isFalse);
    expect(result.message, contains('chưa gửi'));
    expect(commands.calls, hasLength(1));
  });
}
