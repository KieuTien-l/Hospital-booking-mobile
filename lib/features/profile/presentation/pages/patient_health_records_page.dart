import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/widgets/view_state_widgets.dart';
import '../../../health_records/domain/entities/health_record.dart';
import '../../../health_records/presentation/controllers/health_record_controller.dart';
import '../../domain/entities/patient.dart';
import '../controllers/patient_profile_controller.dart';
import '../widgets/health_records_date_filter.dart';

/// KieuTien's Health Record layout, wired to the live HO_SO_SUC_KHOE data.
class PatientHealthRecordsPage extends StatefulWidget {
  const PatientHealthRecordsPage({super.key, this.patient, this.initialDate});

  /// A profile can be supplied when viewing a chosen family member. When it is
  /// omitted, the signed-in patient's profile is read from the provider.
  final Patient? patient;
  final DateTime? initialDate;

  @override
  State<PatientHealthRecordsPage> createState() =>
      _PatientHealthRecordsPageState();
}

class _PatientHealthRecordsPageState extends State<PatientHealthRecordsPage> {
  static const _tabs = <_HealthRecordTab>[
    _HealthRecordTab('Khám bệnh', HealthRecordType.outpatient),
    _HealthRecordTab('Nhập viện', HealthRecordType.inpatient),
    _HealthRecordTab('Khám sức khỏe', HealthRecordType.checkup),
  ];
  static const _categories = <_HealthRecordCategory>[
    _HealthRecordCategory('Tất cả'),
    _HealthRecordCategory('Đơn thuốc', HealthRecordDocumentCategory.prescription),
    _HealthRecordCategory('Phiếu chỉ định', HealthRecordDocumentCategory.order),
    _HealthRecordCategory('Chứng nhận', HealthRecordDocumentCategory.certificate),
  ];

  int _tab = 0;
  int _category = 0;
  String? _loadedPatientId;
  late final DateTime _today;
  late DateTime _from;
  late DateTime _to;

  @override
  void initState() {
    super.initState();
    // Health Record dates follow the project's patient-facing timezone.
    final now =
        widget.initialDate ?? DateTime.now().toUtc().add(const Duration(hours: 7));
    _today = DateTime(now.year, now.month, now.day);
    _to = _today;
    final lastDay = DateTime(now.year - 1, now.month + 1, 0).day;
    _from = DateTime(
      now.year - 1,
      now.month,
      now.day > lastDay ? lastDay : now.day,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRecordsFor(_currentPatientId());
    });
  }

  String? _currentPatientId() =>
      widget.patient?.id ?? context.read<PatientProfileController?>()?.patient?.id;

  void _loadRecordsFor(String? patientId) {
    final controller = context.read<HealthRecordController?>();
    if (!mounted ||
        controller == null ||
        patientId == null ||
        patientId.isEmpty ||
        patientId == _loadedPatientId) {
      return;
    }
    _loadedPatientId = patientId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _loadedPatientId == patientId) {
        controller.loadRecords(patientId);
      }
    });
  }

  Future<void> _pickDate(bool from) async {
    final picked = await showDatePicker(
      context: context,
      helpText: from ? 'Chọn ngày bắt đầu' : 'Chọn ngày kết thúc',
      initialDate: from ? _from : _to,
      firstDate: from ? DateTime(1900) : _from,
      lastDate: from ? _to : _today,
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (from) {
        _from = picked;
      } else {
        _to = picked;
      }
    });
  }

  String get _emptyMessage => switch (_tab) {
    0 => 'Vui lòng thử điều chỉnh bộ lọc ngày hoặc chọn danh mục khác để xem kết quả.',
    1 => 'Vui lòng thử điều chỉnh bộ lọc ngày để xem kết quả.',
    _ => 'Vui lòng thử điều chỉnh bộ lọc ngày để xem kết quả khám sức khỏe.',
  };

  bool _matchesFilter(HealthRecord record) {
    final date = DateTime(
      record.recordDate.year,
      record.recordDate.month,
      record.recordDate.day,
    );
    if (date.isBefore(_from) || date.isAfter(_to)) return false;
    if (record.recordType.trim().toUpperCase() != _tabs[_tab].recordType) {
      return false;
    }

    // The original KieuTien layout exposes document categories for outpatient
    // visits only. Inpatient and checkup records are filtered by their type
    // and date, without being hidden by a document-category selection.
    if (_tab != 0) return true;
    final category = _categories[_category].value;
    if (category == null) return true;
    final recordCategory = record.documentCategory?.trim().toUpperCase();
    if (category == HealthRecordDocumentCategory.prescription) {
      return recordCategory == category ||
          (record.prescription?.trim().isNotEmpty ?? false);
    }
    return recordCategory == category;
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<PatientProfileController?>();
    final patient = widget.patient ?? profile?.patient;
    _loadRecordsFor(patient?.id);

    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: Theme.of(context).textTheme.apply(fontFamily: 'BeVietnamPro'),
      ),
      child: Scaffold(
        backgroundColor: AppColors.primarySoft,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          toolbarHeight: 88,
          centerTitle: true,
          title: patient == null
              ? const Text('Hồ sơ sức khỏe')
              : Column(
                  children: [
                    Text(
                      patient.fullName.toUpperCase(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '(${patient.id})',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
        ),
        body: patient == null
            ? _buildMissingPatient(profile)
            : SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 680),
                    child: LayoutBuilder(
                      builder: (context, constraints) => SingleChildScrollView(
                        padding: const EdgeInsets.only(bottom: 32),
                        child: Column(
                          children: [
                            _buildTabs(context),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              child: HealthRecordsDateFilter(
                                fromDate: _from,
                                toDate: _to,
                                onFromTap: () => _pickDate(true),
                                onToTap: () => _pickDate(false),
                              ),
                            ),
                            if (_tab == 0) _buildCategories(),
                            _buildRecords(patient, constraints.maxHeight),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildMissingPatient(PatientProfileController? profile) {
    if (profile?.isLoading == true) {
      return const AppLoadingWidget(message: 'Đang tải hồ sơ bệnh nhân...');
    }
    return AppEmptyWidget(
      message: profile?.isError == true
          ? (profile?.errorMessage ?? 'Không thể tải hồ sơ bệnh nhân.')
          : 'Vui lòng cập nhật hồ sơ bệnh nhân để xem hồ sơ sức khỏe.',
      icon: Icons.person_off_outlined,
      onRetry: profile?.isError == true ? profile?.refreshPatient : null,
    );
  }

  Widget _buildTabs(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
    child: Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            for (var index = 0; index < _tabs.length; index++)
              Expanded(
                child: Semantics(
                  selected: _tab == index,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => setState(() => _tab = index),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
                      decoration: BoxDecoration(
                        color: _tab == index
                            ? AppColors.primarySoft
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Text(
                            _tabs[index].label,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: _tab == index
                                  ? AppColors.textOnPrimary
                                  : AppColors.textSecondary,
                              fontWeight: _tab == index
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            height: 3,
                            width: 36,
                            decoration: BoxDecoration(
                              color: _tab == index
                                  ? AppColors.textOnPrimary
                                  : AppColors.divider,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );

  Widget _buildCategories() => ColoredBox(
    color: AppColors.surface,
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          for (var index = 0; index < _categories.length; index++)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(_categories[index].label),
                selected: _category == index,
                onSelected: (_) => setState(() => _category = index),
                showCheckmark: false,
                selectedColor: AppColors.textOnPrimary,
                backgroundColor: AppColors.primarySoft,
                side: BorderSide.none,
                shape: const StadiumBorder(),
                labelStyle: TextStyle(
                  color: _category == index
                      ? Colors.white
                      : AppColors.textSecondary,
                ),
              ),
            ),
        ],
      ),
    ),
  );

  Widget _buildRecords(Patient patient, double availableHeight) {
    final controller = context.watch<HealthRecordController?>();
    if (controller == null) return _emptyPanel(_emptyMessage, availableHeight);
    if (controller.isLoading) {
      return const SizedBox(
        height: 260,
        child: AppLoadingWidget(message: 'Đang tải hồ sơ sức khỏe...'),
      );
    }
    if (controller.isError) {
      return SizedBox(
        height: 320,
        child: AppErrorWidget(
          message: controller.errorMessage ?? 'Lỗi không xác định',
          onRetry: () => controller.loadRecords(patient.id),
        ),
      );
    }

    final records = controller.records.where(_matchesFilter).toList();
    if (records.isEmpty) return _emptyPanel(_emptyMessage, availableHeight);
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      itemCount: records.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _HealthRecordCard(record: records[index]),
    );
  }

  Widget _emptyPanel(String message, double availableHeight) => Padding(
    padding: EdgeInsets.fromLTRB(28, availableHeight * .16, 28, 48),
    child: Column(
      children: [
        const CircleAvatar(
          radius: 52,
          backgroundColor: AppColors.background,
          child: Icon(Icons.find_in_page_outlined, size: 62, color: AppColors.disabled),
        ),
        const SizedBox(height: 20),
        Text(
          'Không có kết quả!',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.textSecondary,
            height: 1.6,
          ),
        ),
      ],
    ),
  );
}

class _HealthRecordCard extends StatelessWidget {
  const _HealthRecordCard({required this.record});

  final HealthRecord record;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    elevation: 0,
    color: AppColors.surface,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  DateFormat('dd/MM/yyyy HH:mm').format(record.recordDate),
                  style: const TextStyle(
                    color: AppColors.textOnPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Icon(Icons.favorite, color: AppColors.error, size: 18),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Chẩn đoán: ${record.diagnosis}',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          if (record.prescription?.trim().isNotEmpty ?? false) ...[
            const SizedBox(height: 6),
            Text(
              'Đơn thuốc: ${record.prescription}',
              style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
          ],
          if (record.notes?.trim().isNotEmpty ?? false) ...[
            const SizedBox(height: 6),
            Text(
              'Ghi chú: ${record.notes}',
              style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    ),
  );
}

class _HealthRecordTab {
  const _HealthRecordTab(this.label, this.recordType);

  final String label;
  final String recordType;
}

class _HealthRecordCategory {
  const _HealthRecordCategory(this.label, [this.value]);

  final String label;
  final String? value;
}
