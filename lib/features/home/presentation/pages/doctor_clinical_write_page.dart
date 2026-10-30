import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../appointments/domain/entities/appointment.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../domain/entities/doctor_workspace.dart';
import '../../domain/repositories/doctor_workspace_repository.dart';
import '../controllers/doctor_workspace_controller.dart';
import '../widgets/patient_home_background.dart';

/// A narrow clinical-write surface. Patient/doctor/appointment identifiers are
/// selected from the Worker projection and never typed or trusted by the app.
class DoctorClinicalWritePage extends StatefulWidget {
  const DoctorClinicalWritePage({super.key, this.initialAppointmentId});

  /// Passed from a doctor's slot queue so the physician never has to search
  /// for the patient again before opening the examination sheet.
  final String? initialAppointmentId;

  @override
  State<DoctorClinicalWritePage> createState() =>
      _DoctorClinicalWritePageState();
}

class _DoctorClinicalWritePageState extends State<DoctorClinicalWritePage> {
  static const _clinicalCatalog = <({String name, String type})>[
    (name: 'Công thức máu', type: 'Xét nghiệm'),
    (name: 'Đường huyết', type: 'Xét nghiệm'),
    (name: 'Men gan', type: 'Xét nghiệm'),
    (name: 'Xét nghiệm nước tiểu', type: 'Xét nghiệm'),
    (name: 'Siêu âm bụng', type: 'Siêu âm'),
    (name: 'Siêu âm tim', type: 'Siêu âm'),
    (name: 'X-quang ngực', type: 'X Quang'),
    (name: 'Điện tim', type: 'Khác'),
    (name: 'CT Scan', type: 'CT Scan'),
    (name: 'MRI', type: 'Khác'),
  ];
  static const _medicineCatalog = <String>[
    'Paracetamol',
    'Ibuprofen',
    'Amoxicillin',
    'Azithromycin',
    'Cetirizine',
    'Omeprazole',
    'Metformin',
    'Amlodipine',
    'Losartan',
    'Atorvastatin',
    'Vitamin C',
    'Oresol',
  ];
  final _formKey = GlobalKey<FormState>();
  final _diagnosis = TextEditingController();
  final _notes = TextEditingController();
  final _medicines = <_MedicineInput>[];
  final _testResult = TextEditingController();
  final _conclusion = TextEditingController();
  final _orderName = TextEditingController();
  final _orderNotes = TextEditingController();
  bool _health = true, _saving = false;
  String _recordType = 'OUTPATIENT';
  String _selectedOrderType = 'Xét nghiệm';
  String? _appointmentId, _savedHealthId, _savedResultId, _message;
  String _legacyPrescription = '';
  List<DoctorHealthRecordSummary> _healthRecords = const [];
  List<DoctorTestResultSummary> _testResults = const [];
  List<DoctorClinicalOrderSummary> _clinicalOrders = const [];
  String? _selectedOrderId;
  bool _loadingRecords = false;
  bool _loadingHistory = false;
  int _recordsRequest = 0;
  String? _examinationStatus;

  @override
  void initState() {
    super.initState();
    _appointmentId = widget.initialAppointmentId;
    if (_appointmentId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadExisting());
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _diagnosis,
      _notes,
      _testResult,
      _conclusion,
      _orderName,
      _orderNotes,
    ]) {
      controller.dispose();
    }
    for (final medicine in _medicines) {
      medicine.dispose();
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
      final records = await Future.wait([
        repository.loadHealthRecords(
          userId: userId,
          appointmentId: appointmentId,
        ),
        repository.loadTestResults(
          userId: userId,
          appointmentId: appointmentId,
        ),
        repository.loadClinicalOrders(
          userId: userId,
          appointmentId: appointmentId,
        ),
      ]);
      if (mounted && request == _recordsRequest) {
        setState(() {
          _healthRecords = records[0] as List<DoctorHealthRecordSummary>;
          _testResults = records[1] as List<DoctorTestResultSummary>;
          _clinicalOrders = records[2] as List<DoctorClinicalOrderSummary>;
          if (_testResults.isNotEmpty && _examinationStatus == null) {
            _examinationStatus = 'RESULTS_READY';
          }
        });
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
    if (!_health && (_selectedOrderId == null || _selectedOrderId!.isEmpty)) {
      setState(() => _message = 'Chọn chỉ định CLS trước khi nhập kết quả.');
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
                prescription: _legacyPrescription,
                medicines: _medicines
                    .map((medicine) => medicine.toDraft())
                    .toList(),
                recordType: _recordType,
              ),
            )
          : await repository.saveTestResult(
              userId: userId,
              draft: DoctorTestResultDraft(
                requestId: _requestId(),
                id: _savedResultId,
                appointmentId: appointmentId,
                orderId: _selectedOrderId!,
                testName: _clinicalOrders
                    .firstWhere((order) => order.id == _selectedOrderId)
                    .testName,
                resultDescription: _testResult.text.trim(),
                resultType: _catalogTypeFor(
                  _clinicalOrders.firstWhere(
                    (order) => order.id == _selectedOrderId,
                  ),
                ),
                conclusion: _conclusion.text.trim(),
                referenceRange: '',
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
        if (_health && _testResults.isNotEmpty) {
          _examinationStatus = 'IN_PROGRESS';
        } else if (!_health) {
          _examinationStatus = 'RESULTS_READY';
        }
      });
      await _loadExisting();
      if (!mounted) return;
      await context.read<DoctorWorkspaceController?>()?.refresh();
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

  Future<void> _saveClinicalOrder() async {
    final appointmentId = _appointmentId;
    final repository = context.read<DoctorWorkspaceRepository>();
    final userId = context.read<AuthController>().currentUser?.id ?? '';
    if (appointmentId == null || _orderName.text.trim().isEmpty) {
      setState(() => _message = 'Nhập tên chỉ định CLS.');
      return;
    }
    setState(() => _saving = true);
    try {
      final saved = await repository.createClinicalOrder(
        userId: userId,
        draft: DoctorClinicalOrderDraft(
          requestId: _requestId(),
          appointmentId: appointmentId,
          testName: _orderName.text.trim(),
          resultType: _selectedOrderType,
          notes: _orderNotes.text.trim(),
        ),
      );
      if (!mounted) return;
      setState(() {
        _message = saved.message;
        _orderName.clear();
        _orderNotes.clear();
      });
      await _loadExisting();
    } catch (_) {
      if (mounted) setState(() => _message = 'Không thể thêm chỉ định CLS.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickClinicalOrder() async {
    final selected = await showModalBottomSheet<({String name, String type})>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ClinicalCatalogSheet(items: _clinicalCatalog),
    );
    if (!mounted || selected == null) return;
    setState(() {
      _orderName.text = selected.name;
      _selectedOrderType = selected.type;
    });
  }

  Future<void> _pickMedicine(_MedicineInput medicine) async {
    const custom = '__custom_medicine__';
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _MedicineCatalogSheet(items: _medicineCatalog),
    );
    if (!mounted || selected == null) return;
    if (selected != custom) {
      setState(() => medicine.name.text = selected);
      return;
    }
    final controller = TextEditingController(text: medicine.name.text);
    final manualName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nhập thuốc ngoài danh mục'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 200,
          decoration: const InputDecoration(hintText: 'Tên thuốc'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Chọn'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (!mounted || manualName == null || manualName.isEmpty) return;
    setState(() => medicine.name.text = manualName);
  }

  Future<void> _startExamination() async {
    final appointmentId = _appointmentId;
    final repository = context.read<DoctorWorkspaceRepository>();
    final userId = context.read<AuthController>().currentUser?.id ?? '';
    if (appointmentId == null ||
        userId.isEmpty ||
        !repository.canWriteClinicalRecords) {
      setState(() => _message = 'Hãy chọn lịch khám hợp lệ trước.');
      return;
    }
    setState(() {
      _saving = true;
      _message = null;
    });
    try {
      final result = await repository.startExamination(
        userId: userId,
        appointmentId: appointmentId,
        requestId: _requestId(),
      );
      if (mounted) {
        setState(() {
          _message = result.message;
          _examinationStatus = result.status;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _message = 'Không thể tạo phiếu khám. Vui lòng thử lại.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _markAwaitingResults() async {
    final appointmentId = _appointmentId;
    final repository = context.read<DoctorWorkspaceRepository>();
    final userId = context.read<AuthController>().currentUser?.id ?? '';
    if (appointmentId == null || _healthRecords.isEmpty) {
      setState(() => _message = 'Hãy lưu khám ban đầu và chỉ định CLS trước.');
      return;
    }
    setState(() {
      _saving = true;
      _message = null;
    });
    try {
      final result = await repository.markExaminationAwaitingResults(
        userId: userId,
        appointmentId: appointmentId,
        requestId: _requestId(),
      );
      if (mounted) {
        setState(() {
          _examinationStatus = result.status;
          _message = result.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _message = 'Không thể chuyển sang chờ kết quả CLS.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _completeExamination() async {
    final appointmentId = _appointmentId;
    final repository = context.read<DoctorWorkspaceRepository>();
    final userId = context.read<AuthController>().currentUser?.id ?? '';
    if (appointmentId == null || _healthRecords.isEmpty) {
      setState(() => _message = 'Hãy lưu kết luận khám trước khi hoàn thành.');
      return;
    }
    setState(() {
      _saving = true;
      _message = null;
    });
    try {
      // RESULT_READY means every ordered CLS item has returned.  Re-opening
      // the sheet here is a state transition for the doctor's conclusion,
      // not another examination. It also lets older deployed Workers finish
      // visits that still require IN_PROGRESS at completion time.
      if (_examinationStatus == 'RESULTS_READY') {
        final resumed = await repository.startExamination(
          userId: userId,
          appointmentId: appointmentId,
          requestId: _requestId(),
        );
        if (!mounted) return;
        setState(() => _examinationStatus = resumed.status);
      }
      final result = await repository.completeAppointment(
        userId: userId,
        appointmentId: appointmentId,
        requestId: _requestId(),
      );
      if (!mounted) return;
      setState(() {
        _examinationStatus = result.status;
        _message = result.message;
      });
      await context.read<DoctorWorkspaceController?>()?.refresh();
    } catch (error) {
      if (mounted) {
        setState(() => _message = 'Không thể hoàn thành: ${_errorText(error)}');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _errorText(Object error) {
    final text = error.toString().replaceFirst('Bad state: ', '').trim();
    return text.isEmpty
        ? 'Hãy bảo đảm đã xem kết quả CLS và ghi kết luận.'
        : text;
  }

  String _stageLabel([String? status]) =>
      switch (status ?? _examinationStatus) {
        'IN_PROGRESS' => 'Đang khám',
        'WAITING_RESULTS' => 'Chờ kết quả CLS',
        'RESULTS_READY' => 'Đã có kết quả CLS — chờ kết luận',
        'COMPLETED' => 'Đã hoàn thành',
        _ => 'Chưa mở phiếu khám',
      };

  bool get _hasPendingClinicalOrder =>
      _clinicalOrders.any((order) => order.status != 'RESULT_READY');

  List<DoctorTestResultSummary> get _latestTestResults {
    final latest = <String, DoctorTestResultSummary>{};
    for (final result in _testResults) {
      // The Worker returns records in stable creation order, so assigning
      // again keeps the latest version when legacy duplicate records exist.
      latest[result.testName] = result;
    }
    return latest.values.toList(growable: false);
  }

  String _catalogTypeFor(DoctorClinicalOrderSummary order) =>
      _clinicalCatalog
          .where((item) => item.name == order.testName)
          .map((item) => item.type)
          .firstOrNull ??
      order.resultType;

  InputDecoration _decoration(String label) => InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: AppColors.textSecondary),
    floatingLabelStyle: const TextStyle(color: AppColors.textOnPrimary),
    hintStyle: const TextStyle(color: AppColors.textSecondary),
  );

  @override
  Widget build(BuildContext context) {
    final workspace = context.watch<DoctorWorkspaceController?>();
    final bookings = _eligible(workspace);
    if (_appointmentId != null &&
        !bookings.any((item) => item.appointment.id == _appointmentId)) {
      _appointmentId = null;
    }
    final selectedBooking = _appointmentId == null
        ? null
        : bookings
              .where((booking) => booking.appointment.id == _appointmentId)
              .firstOrNull;
    final isCompleted =
        selectedBooking?.appointment.status == AppointmentStatus.completed ||
        _examinationStatus == 'COMPLETED';
    final examinationStatus =
        _examinationStatus ?? selectedBooking?.appointment.clinicalStatus;
    return Theme(
      data: Theme.of(context).copyWith(
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textOnPrimary,
            disabledForegroundColor: AppColors.textSecondary,
            disabledIconColor: AppColors.textSecondary,
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: AppColors.textOnPrimary,
            disabledForegroundColor: AppColors.textSecondary,
            disabledIconColor: AppColors.textSecondary,
          ),
        ),
      ),
      child: PatientHomeBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            title: const Text(
              'Hồ sơ khám và CLS',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
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
                            _examinationStatus = null;
                            _legacyPrescription = '';
                            for (final medicine in _medicines) {
                              medicine.dispose();
                            }
                            _medicines.clear();
                          });
                          _loadExisting();
                        },
                ),
                if (_appointmentId != null) ...[
                  Card(
                    color: AppColors.primarySoft,
                    child: ListTile(
                      leading: const Icon(Icons.medical_information_outlined),
                      title: const Text('Trạng thái phiếu khám'),
                      subtitle: Text(_stageLabel(examinationStatus)),
                    ),
                  ),
                  const SizedBox(height: 8),
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
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _saving || isCompleted
                        ? null
                        : _startExamination,
                    icon: const Icon(Icons.note_add_outlined),
                    label: Text(
                      examinationStatus == 'RESULTS_READY'
                          ? 'Mở phiếu khám để kết luận'
                          : 'Bắt đầu khám và tạo phiếu khám',
                    ),
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
                if (!isCompleted)
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
                if (!isCompleted)
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            _health
                                ? Icons.save_outlined
                                : Icons.science_outlined,
                          ),
                    label: Text(
                      _health
                          ? (_savedHealthId != null
                                ? 'Cập nhật hồ sơ khám'
                                : 'Lưu hồ sơ khám')
                          : (_savedResultId != null
                                ? 'Cập nhật kết quả CLS'
                                : 'Lưu kết quả CLS'),
                    ),
                  ),
                if (!isCompleted &&
                    examinationStatus == 'IN_PROGRESS' &&
                    _hasPendingClinicalOrder) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _saving ? null : _markAwaitingResults,
                    icon: const Icon(Icons.science_outlined),
                    label: const Text('Chuyển chờ kết quả CLS'),
                  ),
                ],
                if (!isCompleted &&
                    (examinationStatus == 'IN_PROGRESS' ||
                        examinationStatus == 'RESULTS_READY') &&
                    _healthRecords.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: _saving ? null : _completeExamination,
                    icon: const Icon(Icons.task_alt_outlined),
                    label: const Text('Hoàn thành khám'),
                  ),
                ],
              ],
            ),
          ),
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
    if (_health) {
      return Card(
        margin: const EdgeInsets.only(bottom: 16),
        child: Column(
          children: [
            const ListTile(title: Text('Hồ sơ khám — chạm để sửa')),
            if (_healthRecords.isEmpty)
              const ListTile(title: Text('Chưa lưu khám ban đầu.')),
            for (final record in _healthRecords)
              ListTile(
                title: Text(record.diagnosis),
                subtitle: _healthRecordSummary(record),
                trailing: const Icon(Icons.edit_outlined),
                onTap: () => setState(() {
                  _savedHealthId = record.id;
                  _diagnosis.text = record.diagnosis;
                  _notes.text = record.notes;
                  for (final medicine in _medicines) {
                    medicine.dispose();
                  }
                  _medicines.clear();
                  _medicines.addAll(
                    record.medicines.map(_MedicineInput.fromMedicine),
                  );
                  _legacyPrescription = record.medicines.isEmpty
                      ? record.prescription
                      : '';
                  _recordType = record.recordType;
                }),
              ),
          ],
        ),
      );
    }
    if (!_health && _latestTestResults.isNotEmpty) {
      return Card(
        margin: const EdgeInsets.only(bottom: 16),
        child: Column(
          children: [
            const ListTile(title: Text('Kết quả CLS đã lập — chạm để sửa')),
            for (final record in _latestTestResults)
              ListTile(
                title: Text(record.testName),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(record.resultType),
                    if (record.resultDescription.trim().isNotEmpty)
                      Text(
                        'Kết quả: ${record.resultDescription}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (record.conclusion.trim().isNotEmpty)
                      Text(
                        'Kết luận: ${record.conclusion}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
                isThreeLine:
                    record.resultDescription.trim().isNotEmpty ||
                    record.conclusion.trim().isNotEmpty,
                trailing: const Icon(Icons.edit_outlined),
                onTap: () => setState(() {
                  _savedResultId = record.id;
                  _selectedOrderId =
                      record.orderId ??
                      _clinicalOrders
                          .where((order) => order.testName == record.testName)
                          .firstOrNull
                          ?.id;
                  _testResult.text = record.resultDescription;
                  _conclusion.text = record.conclusion;
                }),
              ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _healthRecordSummary(DoctorHealthRecordSummary record) {
    final medicineNames = record.medicines
        .take(2)
        .map((medicine) => medicine.name)
        .join(', ');
    final prescription = record.medicines.isNotEmpty
        ? 'Đơn thuốc: $medicineNames${record.medicines.length > 2 ? '…' : ''}'
        : record.prescription.trim().isNotEmpty
        ? 'Đơn thuốc: ${record.prescription}'
        : '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(record.recordType),
        if (record.notes.trim().isNotEmpty)
          Text(
            'Ghi chú: ${record.notes}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        if (prescription.isNotEmpty)
          Text(prescription, maxLines: 2, overflow: TextOverflow.ellipsis),
      ],
    );
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
      InkWell(
        onTap: _saving ? null : _pickClinicalOrder,
        child: InputDecorator(
          decoration: _decoration('Tên chỉ định CLS (chọn từ danh mục)'),
          child: Text(
            _orderName.text.isEmpty ? 'Chọn chỉ định CLS' : _orderName.text,
            style: TextStyle(
              color: _orderName.text.isEmpty
                  ? AppColors.textSecondary
                  : AppColors.textPrimary,
            ),
          ),
        ),
      ),
      TextButton.icon(
        onPressed: _saving ? null : () => setState(() => _orderName.clear()),
        icon: const Icon(Icons.edit_outlined),
        label: const Text('Yêu cầu đặc biệt / nhập thủ công'),
      ),
      if (_orderName.text.isEmpty)
        TextFormField(
          controller: _orderName,
          decoration: _decoration('Nhập yêu cầu đặc biệt'),
          maxLength: 300,
        ),
      TextFormField(
        controller: _orderNotes,
        decoration: _decoration('Ghi chú chỉ định'),
        maxLines: 2,
        maxLength: 1000,
      ),
      OutlinedButton.icon(
        onPressed: _saving ? null : _saveClinicalOrder,
        icon: const Icon(Icons.add),
        label: const Text('Thêm chỉ định CLS'),
      ),
      if (_clinicalOrders.isNotEmpty)
        Card(
          margin: const EdgeInsets.only(top: 12),
          child: Column(
            children: [
              const ListTile(title: Text('Chỉ định CLS đã thêm')),
              for (final order in _clinicalOrders)
                ListTile(
                  leading: const Icon(Icons.science_outlined),
                  title: Text(order.testName),
                  subtitle: Text('${order.resultType} • ${order.status}'),
                ),
            ],
          ),
        ),
      if (_clinicalOrders.isNotEmpty) const SizedBox(height: 16),
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
      const SizedBox(height: 12),
      _prescriptionFields(),
    ],
  );

  Widget _prescriptionFields() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Đơn thuốc',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 4),
      const Text(
        'Thêm từng thuốc kèm liều dùng để bệnh nhân xem rõ ràng.',
        style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
      ),
      if (_legacyPrescription.isNotEmpty && _medicines.isEmpty) ...[
        const SizedBox(height: 8),
        Card(
          margin: EdgeInsets.zero,
          color: AppColors.surface,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text('Đơn thuốc cũ: $_legacyPrescription'),
          ),
        ),
      ],
      for (var index = 0; index < _medicines.length; index++) ...[
        const SizedBox(height: 10),
        _medicineCard(index, _medicines[index]),
      ],
      const SizedBox(height: 10),
      OutlinedButton.icon(
        onPressed: _saving
            ? null
            : () => setState(() => _medicines.add(_MedicineInput())),
        icon: const Icon(Icons.add),
        label: const Text('Thêm thuốc'),
      ),
    ],
  );

  Widget _medicineCard(int index, _MedicineInput medicine) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Thuốc ${index + 1}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                tooltip: 'Xóa thuốc',
                onPressed: _saving
                    ? null
                    : () => setState(() {
                        final removed = _medicines.removeAt(index);
                        removed.dispose();
                      }),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          TextFormField(
            controller: medicine.name,
            readOnly: true,
            onTap: _saving ? null : () => _pickMedicine(medicine),
            decoration: _decoration('Tên thuốc *').copyWith(
              hintText: 'Chọn thuốc từ danh mục',
              suffixIcon: const Icon(Icons.arrow_drop_down),
            ),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Chọn thuốc hoặc xóa dòng này.'
                : null,
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: medicine.strength,
            decoration: _decoration('Hàm lượng (VD: 500 mg)'),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: medicine.quantity,
            decoration: _decoration('Số lượng (VD: 10 viên)'),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: medicine.dose,
            decoration: _decoration('Liều mỗi lần (VD: 1 viên)'),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: medicine.frequency,
            decoration: _decoration('Số lần/ngày (VD: 2 lần/ngày)'),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: medicine.duration,
            decoration: _decoration('Số ngày dùng (VD: 5 ngày)'),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: medicine.instructions,
            decoration: _decoration('Cách dùng / lưu ý'),
            maxLines: 2,
          ),
        ],
      ),
    ),
  );

  Widget _resultFields() {
    return Column(
      children: [
        DropdownButtonFormField<String>(
          initialValue: _selectedOrderId,
          decoration: _decoration('Chỉ định CLS'),
          items: _clinicalOrders
              .map(
                (order) => DropdownMenuItem(
                  value: order.id,
                  child: Text(order.testName),
                ),
              )
              .toList(),
          onChanged: (value) => setState(() {
            _selectedOrderId = value;
            _savedResultId = null;
            _testResult.clear();
            _conclusion.clear();
          }),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _testResult,
          decoration: _decoration('Kết quả'),
          maxLines: 4,
          maxLength: 4000,
          validator: (value) =>
              value == null || value.trim().isEmpty ? 'Nhập kết quả.' : null,
        ),
        TextFormField(
          controller: _conclusion,
          decoration: _decoration('Kết luận'),
          maxLines: 3,
          maxLength: 2000,
        ),
      ],
    );
  }
}

class _MedicineInput {
  _MedicineInput();

  _MedicineInput.fromMedicine(DoctorPrescriptionMedicine medicine) {
    name.text = medicine.name;
    strength.text = medicine.strength;
    quantity.text = medicine.quantity;
    dose.text = medicine.dose;
    frequency.text = medicine.frequency;
    duration.text = medicine.duration;
    instructions.text = medicine.instructions;
  }

  final name = TextEditingController();
  final strength = TextEditingController();
  final quantity = TextEditingController();
  final dose = TextEditingController();
  final frequency = TextEditingController();
  final duration = TextEditingController();
  final instructions = TextEditingController();

  DoctorPrescriptionMedicine toDraft() => DoctorPrescriptionMedicine(
    name: name.text.trim(),
    strength: strength.text.trim(),
    quantity: quantity.text.trim(),
    dose: dose.text.trim(),
    frequency: frequency.text.trim(),
    duration: duration.text.trim(),
    instructions: instructions.text.trim(),
  );

  void dispose() {
    for (final controller in [
      name,
      strength,
      quantity,
      dose,
      frequency,
      duration,
      instructions,
    ]) {
      controller.dispose();
    }
  }
}

class _MedicineCatalogSheet extends StatefulWidget {
  const _MedicineCatalogSheet({required this.items});

  final List<String> items;

  @override
  State<_MedicineCatalogSheet> createState() => _MedicineCatalogSheetState();
}

class _MedicineCatalogSheetState extends State<_MedicineCatalogSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final needle = _query.toLowerCase();
    final items = widget.items
        .where((item) => item.toLowerCase().contains(needle))
        .toList(growable: false);
    return SafeArea(
      child: FractionallySizedBox(
        heightFactor: .75,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Text(
                'Danh mục thuốc',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              TextField(
                autofocus: true,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Tìm tên thuốc',
                ),
                onChanged: (value) => setState(() => _query = value.trim()),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Nhập thuốc ngoài danh mục'),
                onTap: () => Navigator.pop(context, '__custom_medicine__'),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, index) => ListTile(
                    leading: const Icon(Icons.medication_outlined),
                    title: Text(items[index]),
                    onTap: () => Navigator.pop(context, items[index]),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClinicalCatalogSheet extends StatefulWidget {
  const _ClinicalCatalogSheet({required this.items});
  final List<({String name, String type})> items;

  @override
  State<_ClinicalCatalogSheet> createState() => _ClinicalCatalogSheetState();
}

class _ClinicalCatalogSheetState extends State<_ClinicalCatalogSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final needle = _query.toLowerCase();
    final items = widget.items
        .where((item) => item.name.toLowerCase().contains(needle))
        .toList(growable: false);
    return SafeArea(
      child: FractionallySizedBox(
        heightFactor: .75,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Text(
                'Danh mục chỉ định CLS',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              TextField(
                autofocus: true,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Tìm tên CLS',
                ),
                onChanged: (value) => setState(() => _query = value.trim()),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, index) => ListTile(
                    title: Text(items[index].name),
                    subtitle: Text(items[index].type),
                    onTap: () => Navigator.pop(context, items[index]),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
          const SizedBox(height: 20),
          Text(
            'Lần khám (${history.visits.length})',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          if (history.visits.isEmpty)
            const Text(
              'Chưa có lần khám trước đó.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          for (final visit in history.visits) ...[
            _visitCard(
              visit,
              history.healthRecords
                  .where((record) => record.appointmentId == visit.id)
                  .toList(growable: false),
              history.testResults
                  .where((result) => result.appointmentId == visit.id)
                  .toList(growable: false),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    ),
  );

  Widget _visitCard(
    DoctorPatientVisit visit,
    List<DoctorHealthRecordSummary> records,
    List<DoctorTestResultSummary> results,
  ) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_month_outlined),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${visit.date.day.toString().padLeft(2, '0')}/${visit.date.month.toString().padLeft(2, '0')}/${visit.date.year}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      visit.status == 'COMPLETED'
                          ? 'Đã hoàn tất'
                          : 'Đã xác nhận',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              if (visit.startTime.isNotEmpty)
                Text(
                  visit.startTime,
                  style: const TextStyle(
                    color: AppColors.textOnPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          const Divider(height: 24),
          _visitSectionTitle(Icons.folder_shared_outlined, 'Hồ sơ khám'),
          if (records.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'Chưa lập hồ sơ khám.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          for (final record in records) _healthRecordContent(record),
          const Divider(height: 24),
          _visitSectionTitle(Icons.science_outlined, 'Kết quả CLS'),
          if (results.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'Chưa có kết quả CLS.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          for (final result in results) _testResultContent(result),
        ],
      ),
    ),
  );

  Widget _visitSectionTitle(IconData icon, String title) => Row(
    children: [
      Icon(icon, size: 18, color: AppColors.textOnPrimary),
      const SizedBox(width: 7),
      Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
    ],
  );

  Widget _healthRecordContent(DoctorHealthRecordSummary record) {
    final medicines = record.medicines
        .take(2)
        .map((medicine) => medicine.name)
        .join(', ');
    final prescription = record.medicines.isNotEmpty
        ? 'Đơn thuốc: $medicines${record.medicines.length > 2 ? '…' : ''}'
        : record.prescription.trim().isNotEmpty
        ? 'Đơn thuốc đã kê'
        : '';
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Chẩn đoán: ${record.diagnosis}'),
          Text(
            _recordTypeLabel(record.recordType),
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          if (record.notes.trim().isNotEmpty)
            Text(
              'Ghi chú: ${record.notes}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          if (prescription.isNotEmpty) ...[
            const SizedBox(height: 6),
            const Text(
              'Đơn thuốc',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            Text(prescription),
          ],
        ],
      ),
    );
  }

  Widget _testResultContent(DoctorTestResultSummary result) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          result.testName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        Text(
          result.resultType,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        if (result.resultDescription.trim().isNotEmpty)
          Text(
            'Kết quả: ${result.resultDescription}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        if (result.conclusion.trim().isNotEmpty)
          Text(
            'Kết luận: ${result.conclusion}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
      ],
    ),
  );

  String _recordTypeLabel(String value) => switch (value) {
    'INPATIENT' => 'Điều trị nội trú',
    'CHECKUP' => 'Khám sức khỏe',
    _ => 'Khám ngoại trú',
  };
}
