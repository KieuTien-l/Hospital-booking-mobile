import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../appointments/domain/entities/appointment.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../domain/entities/doctor_workspace.dart';
import '../../domain/repositories/doctor_workspace_repository.dart';
import '../controllers/doctor_workspace_controller.dart';

/// A narrow clinical-write surface. Patient/doctor/appointment identifiers are
/// selected from the Worker projection and never typed or trusted by the app.
class DoctorClinicalWritePage extends StatefulWidget {
  const DoctorClinicalWritePage({super.key});

  @override
  State<DoctorClinicalWritePage> createState() =>
      _DoctorClinicalWritePageState();
}

class _DoctorClinicalWritePageState extends State<DoctorClinicalWritePage> {
  final _formKey = GlobalKey<FormState>();
  final _diagnosis = TextEditingController();
  final _notes = TextEditingController();
  final _prescription = TextEditingController();
  final _testName = TextEditingController();
  final _testResult = TextEditingController();
  final _conclusion = TextEditingController();
  final _referenceRange = TextEditingController();
  bool _health = true, _saving = false;
  String _recordType = 'OUTPATIENT', _resultType = 'Khác';
  String? _appointmentId, _savedHealthId, _savedResultId, _message;
  List<DoctorHealthRecordSummary> _healthRecords = const [];
  List<DoctorTestResultSummary> _testResults = const [];
  bool _loadingRecords = false;
  bool _loadingHistory = false;
  int _recordsRequest = 0;

  @override
  void dispose() {
    for (final controller in [
      _diagnosis,
      _notes,
      _prescription,
      _testName,
      _testResult,
      _conclusion,
      _referenceRange,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  String _requestId() =>
      'clinical-${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';

  Future<void> _loadExisting() async {
    final appointmentId = _appointmentId;
    final repository = context.read<DoctorWorkspaceRepository>();
    final userId = context.read<AuthController>().currentUser?.id ?? '';
    if (appointmentId == null ||
        userId.isEmpty ||
        !repository.canWriteClinicalRecords) {
      if (mounted) {
        setState(() {
          _healthRecords = const [];
          _testResults = const [];
          _loadingRecords = false;
        });
      }
      return;
    }
    final request = ++_recordsRequest;
    setState(() => _loadingRecords = true);
    try {
      if (_health) {
        final records = await repository.loadHealthRecords(
          userId: userId,
          appointmentId: appointmentId,
        );
        if (mounted && request == _recordsRequest) {
          setState(() => _healthRecords = records);
        }
      } else {
        final records = await repository.loadTestResults(
          userId: userId,
          appointmentId: appointmentId,
        );
        if (mounted && request == _recordsRequest) {
          setState(() => _testResults = records);
        }
      }
    } catch (_) {
      if (mounted && request == _recordsRequest) {
        setState(() => _message = 'Không tải được hồ sơ đã lập.');
      }
    } finally {
      if (mounted && request == _recordsRequest) {
        setState(() => _loadingRecords = false);
      }
    }
  }

  List<DoctorBooking> _eligible(DoctorWorkspaceController? workspace) =>
      (workspace?.data?.bookings ?? const <DoctorBooking>[])
          .where(
            (booking) =>
                booking.appointment.status == AppointmentStatus.confirmed ||
                booking.appointment.status == AppointmentStatus.completed,
          )
          .toList(growable: false);

  Future<void> _showPatientHistory(List<DoctorBooking> bookings) async {
    final appointmentId = _appointmentId;
    final booking = appointmentId == null
        ? null
        : bookings
              .where((item) => item.appointment.id == appointmentId)
              .firstOrNull;
    final repository = context.read<DoctorWorkspaceRepository>();
    final userId = context.read<AuthController>().currentUser?.id ?? '';
    if (booking == null || userId.isEmpty) return;
    setState(() => _loadingHistory = true);
    try {
      final history = await repository.loadPatientHistory(
        userId: userId,
        patientId: booking.appointment.patientId,
      );
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => _PatientHistorySheet(
          patientName: booking.patientName,
          history: history,
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(() => _message = 'Không tải được lịch sử khám của bệnh nhân.');
      }
    } finally {
      if (mounted) setState(() => _loadingHistory = false);
    }
  }

  Future<void> _save() async {
    final repository = context.read<DoctorWorkspaceRepository>();
    final userId = context.read<AuthController>().currentUser?.id ?? '';
    final appointmentId = _appointmentId;
    if (appointmentId == null || appointmentId.isEmpty) {
      setState(
        () => _message = 'Hãy chọn lịch khám đã xác nhận hoặc hoàn tất.',
      );
      return;
    }
    if (!_formKey.currentState!.validate() ||
        !repository.canWriteClinicalRecords ||
        userId.isEmpty) {
      if (!repository.canWriteClinicalRecords) {
        setState(() => _message = 'Chưa cấu hình dịch vụ hồ sơ y tế bác sĩ.');
      }
      return;
    }
    setState(() {
      _saving = true;
      _message = null;
    });
    try {
      final saved = _health
          ? await repository.saveHealthRecord(
              userId: userId,
              draft: DoctorHealthRecordDraft(
                requestId: _requestId(),
                id: _savedHealthId,
                appointmentId: appointmentId,
                diagnosis: _diagnosis.text.trim(),
                notes: _notes.text.trim(),
                prescription: _prescription.text.trim(),
                recordType: _recordType,
              ),
            )
          : await repository.saveTestResult(
              userId: userId,
              draft: DoctorTestResultDraft(
                requestId: _requestId(),
                id: _savedResultId,
                appointmentId: appointmentId,
                testName: _testName.text.trim(),
                resultDescription: _testResult.text.trim(),
                resultType: _resultType,
                conclusion: _conclusion.text.trim(),
                referenceRange: _referenceRange.text.trim(),
              ),
            );
      if (!mounted) {
        return;
      }
      setState(() {
        if (_health) {
          _savedHealthId = saved.id;
        } else {
          _savedResultId = saved.id;
        }
        _message = saved.message;
      });
      await _loadExisting();
    } catch (_) {
      if (mounted) {
        setState(
          () => _message = 'Không thể lưu. Kiểm tra lịch khám và thử lại.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  InputDecoration _decoration(String label) =>
      InputDecoration(labelText: label);

  @override
  Widget build(BuildContext context) {
    final workspace = context.watch<DoctorWorkspaceController?>();
    final bookings = _eligible(workspace);
    if (_appointmentId != null &&
        !bookings.any((item) => item.appointment.id == _appointmentId)) {
      _appointmentId = null;
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Hồ sơ khám và CLS')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Chỉ ghi cho lịch khám đã xác nhận hoặc hoàn tất. Ngày lập do máy chủ ghi; không thể đổi bệnh nhân, bác sĩ hoặc lịch hẹn.',
              style: TextStyle(color: AppColors.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _appointmentId,
              isExpanded: true,
              decoration: _decoration('Lịch khám / bệnh nhân'),
              items: bookings
                  .map(
                    (booking) => DropdownMenuItem(
                      value: booking.appointment.id,
                      child: Text(
                        '${booking.patientName} • ${booking.appointment.startTime ?? '—'}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: _saving
                  ? null
                  : (value) {
                      setState(() {
                        _appointmentId = value;
                        _savedHealthId = null;
                        _savedResultId = null;
                      });
                      _loadExisting();
                    },
            ),
            if (_appointmentId != null) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _saving || _loadingHistory
                    ? null
                    : () => _showPatientHistory(bookings),
                icon: _loadingHistory
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.history_edu_outlined),
                label: const Text('Lịch sử khám của bệnh nhân'),
              ),
            ],
            if (bookings.isEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'Ngày đang chọn chưa có lịch đã xác nhận/hoàn tất để ghi hồ sơ.',
                style: TextStyle(color: AppColors.error),
              ),
            ],
            const SizedBox(height: 20),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: true,
                  icon: Icon(Icons.folder_shared_outlined),
                  label: Text('Hồ sơ khám'),
                ),
                ButtonSegment(
                  value: false,
                  icon: Icon(Icons.science_outlined),
                  label: Text('Kết quả CLS'),
                ),
              ],
              selected: {_health},
              onSelectionChanged: _saving
                  ? null
                  : (value) {
                      setState(() => _health = value.first);
                      _loadExisting();
                    },
            ),
            const SizedBox(height: 20),
            _existingRecords(),
            Form(
              key: _formKey,
              child: _health ? _healthFields() : _resultFields(),
            ),
            if (_message != null) ...[
              const SizedBox(height: 12),
              Text(
                _message!,
                style: TextStyle(
                  color: _message!.startsWith('Đã')
                      ? AppColors.success
                      : AppColors.error,
                ),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      _health ? Icons.save_outlined : Icons.science_outlined,
                    ),
              label: Text(
                _health && _savedHealthId != null ||
                        !_health && _savedResultId != null
                    ? 'Cập nhật lại'
                    : 'Lưu hồ sơ',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _existingRecords() {
    if (_appointmentId == null) return const SizedBox.shrink();
    if (_loadingRecords) {
      return const Padding(
        padding: EdgeInsets.only(bottom: 16),
        child: LinearProgressIndicator(),
      );
    }
    if (_health && _healthRecords.isNotEmpty) {
      return Card(
        margin: const EdgeInsets.only(bottom: 16),
        child: Column(
          children: [
            const ListTile(title: Text('Hồ sơ đã lập — chạm để sửa')),
            for (final record in _healthRecords)
              ListTile(
                title: Text(record.diagnosis),
                subtitle: Text(record.recordType),
                trailing: const Icon(Icons.edit_outlined),
                onTap: () => setState(() {
                  _savedHealthId = record.id;
                  _diagnosis.text = record.diagnosis;
                  _notes.text = record.notes;
                  _prescription.text = record.prescription;
                  _recordType = record.recordType;
                }),
              ),
          ],
        ),
      );
    }
    if (!_health && _testResults.isNotEmpty) {
      return Card(
        margin: const EdgeInsets.only(bottom: 16),
        child: Column(
          children: [
            const ListTile(title: Text('Kết quả CLS đã lập — chạm để sửa')),
            for (final record in _testResults)
              ListTile(
                title: Text(record.testName),
                subtitle: Text(record.resultType),
                trailing: const Icon(Icons.edit_outlined),
                onTap: () => setState(() {
                  _savedResultId = record.id;
                  _testName.text = record.testName;
                  _testResult.text = record.resultDescription;
                  _resultType = record.resultType;
                  _conclusion.text = record.conclusion;
                  _referenceRange.text = record.referenceRange;
                }),
              ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _healthFields() => Column(
    children: [
      TextFormField(
        controller: _diagnosis,
        decoration: _decoration('Chẩn đoán'),
        maxLength: 1000,
        validator: (value) =>
            value == null || value.trim().isEmpty ? 'Nhập chẩn đoán.' : null,
      ),
      DropdownButtonFormField<String>(
        initialValue: _recordType,
        decoration: _decoration('Loại hồ sơ'),
        items: const [
          DropdownMenuItem(value: 'OUTPATIENT', child: Text('Khám ngoại trú')),
          DropdownMenuItem(value: 'INPATIENT', child: Text('Điều trị nội trú')),
          DropdownMenuItem(value: 'CHECKUP', child: Text('Khám sức khỏe')),
        ],
        onChanged: (value) =>
            setState(() => _recordType = value ?? 'OUTPATIENT'),
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _notes,
        decoration: _decoration('Ghi chú'),
        maxLines: 4,
        maxLength: 4000,
      ),
      TextFormField(
        controller: _prescription,
        decoration: _decoration('Đơn thuốc / chỉ định'),
        maxLines: 4,
        maxLength: 4000,
      ),
    ],
  );

  Widget _resultFields() => Column(
    children: [
      TextFormField(
        controller: _testName,
        decoration: _decoration('Tên xét nghiệm / CLS'),
        maxLength: 300,
        validator: (value) => value == null || value.trim().isEmpty
            ? 'Nhập tên xét nghiệm.'
            : null,
      ),
      TextFormField(
        controller: _testResult,
        decoration: _decoration('Kết quả'),
        maxLines: 4,
        maxLength: 4000,
        validator: (value) =>
            value == null || value.trim().isEmpty ? 'Nhập kết quả.' : null,
      ),
      DropdownButtonFormField<String>(
        initialValue: _resultType,
        decoration: _decoration('Loại cận lâm sàng'),
        items: const [
          DropdownMenuItem(value: 'Xét nghiệm', child: Text('Xét nghiệm')),
          DropdownMenuItem(value: 'Siêu âm', child: Text('Siêu âm')),
          DropdownMenuItem(value: 'X Quang', child: Text('X Quang')),
          DropdownMenuItem(value: 'CT Scan', child: Text('CT Scan')),
          DropdownMenuItem(value: 'Khác', child: Text('Khác')),
        ],
        onChanged: (value) => setState(() => _resultType = value ?? 'Khác'),
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _conclusion,
        decoration: _decoration('Kết luận'),
        maxLines: 3,
        maxLength: 2000,
      ),
      TextFormField(
        controller: _referenceRange,
        decoration: _decoration('Chỉ số tham chiếu'),
        maxLength: 500,
      ),
    ],
  );
}

class _PatientHistorySheet extends StatelessWidget {
  const _PatientHistorySheet({
    required this.patientName,
    required this.history,
  });

  final String patientName;
  final DoctorPatientHistory history;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      minChildSize: 0.45,
      maxChildSize: 0.94,
      builder: (_, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Lịch sử khám: $patientName',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            'Chỉ hiển thị lịch và hồ sơ do chính bạn lập cho bệnh nhân này.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          Text(
            'Lần khám (${history.visits.length})',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          for (final visit in history.visits)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_note_outlined),
              title: Text(
                '${visit.date.day.toString().padLeft(2, '0')}/${visit.date.month.toString().padLeft(2, '0')}/${visit.date.year}',
              ),
              subtitle: Text(
                visit.status == 'COMPLETED' ? 'Đã hoàn tất' : 'Đã xác nhận',
              ),
            ),
          const Divider(height: 30),
          Text(
            'Hồ sơ khám (${history.healthRecords.length})',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          if (history.healthRecords.isEmpty)
            const Text('Chưa có hồ sơ khám trước đó.'),
          for (final record in history.healthRecords)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(record.diagnosis),
              subtitle: Text(
                record.notes.isEmpty ? record.recordType : record.notes,
              ),
            ),
          const Divider(height: 30),
          Text(
            'Kết quả CLS (${history.testResults.length})',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          if (history.testResults.isEmpty)
            const Text('Chưa có kết quả CLS trước đó.'),
          for (final result in history.testResults)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(result.testName),
              subtitle: Text(
                result.conclusion.isEmpty
                    ? result.resultDescription
                    : result.conclusion,
              ),
            ),
        ],
      ),
    ),
  );
}
