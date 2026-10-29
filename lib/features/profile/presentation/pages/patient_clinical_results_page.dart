import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/widgets/view_state_widgets.dart';
import '../../../home/presentation/widgets/patient_home_background.dart';
import '../../../results/domain/entities/test_result.dart';
import '../../../results/presentation/controllers/test_result_controller.dart';
import '../../domain/entities/patient.dart';
import '../widgets/clinical_results_year_filter.dart';
import 'test_result_detail_page.dart';

/// KieuTien's clinical-results UI, connected to QuocViet's patient result
/// controller. The selected patient is passed explicitly so linked profiles
/// never accidentally load the signed-in account holder's records.
class PatientClinicalResultsPage extends StatefulWidget {
  const PatientClinicalResultsPage({
    super.key,
    required this.patient,
    this.initialDate,
  });

  final Patient patient;
  final DateTime? initialDate;

  @override
  State<PatientClinicalResultsPage> createState() =>
      _PatientClinicalResultsPageState();
}

class _PatientClinicalResultsPageState
    extends State<PatientClinicalResultsPage> {
  static const _types = [
    'Xét nghiệm',
    'Siêu âm',
    'X Quang',
    'CT Scan',
    'MRI',
    'Nội soi',
  ];

  var _selectedType = 0;
  late final int _currentYear;
  late int _year;
  late final List<GlobalKey> _typeKeys;

  @override
  void initState() {
    super.initState();
    _typeKeys = List.generate(_types.length, (_) => GlobalKey());
    _currentYear = (widget.initialDate ?? DateTime.now()).year;
    _year = _currentYear;
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadResults());
  }

  @override
  void didUpdateWidget(covariant PatientClinicalResultsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.patient.id != widget.patient.id) _loadResults();
  }

  void _loadResults() {
    if (!mounted) return;
    context.read<TestResultController?>()?.loadResults(widget.patient.id);
  }

  void _selectType(int index) {
    setState(() => _selectedType = index);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final chipContext = _typeKeys[index].currentContext;
      if (chipContext != null) {
        Scrollable.ensureVisible(
          chipContext,
          alignment: .5,
          duration: const Duration(milliseconds: 200),
        );
      }
    });
  }

  Future<void> _chooseType() async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (context) => SafeArea(
        top: false,
        child: FractionallySizedBox(
          heightFactor: .8,
          child: Column(
            children: [
              ListTile(
                title: const Text(
                  'Chọn loại cận lâm sàng',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                trailing: IconButton(
                  tooltip: 'Đóng',
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: _types.length,
                  itemBuilder: (context, index) => ListTile(
                    title: Text(_types[index]),
                    selected: index == _selectedType,
                    selectedColor: AppColors.textOnPrimary,
                    trailing: index == _selectedType
                        ? const Icon(
                            Icons.check,
                            color: AppColors.textOnPrimary,
                          )
                        : null,
                    onTap: () => Navigator.of(context).pop(index),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected != null && mounted) _selectType(selected);
  }

  List<TestResult> _filteredResults(List<TestResult> results) => results
      .where((result) => result.testDate.year == _year)
      .where((result) => _matchesSelectedType(result.resultType))
      .toList();

  bool _matchesSelectedType(String source) {
    final value = source.trim().toLowerCase();
    switch (_types[_selectedType]) {
      case 'Xét nghiệm':
        return value.isEmpty ||
            value == 'khác' ||
            value.contains('xét') ||
            value.contains('xet') ||
            value.contains('laboratory');
      case 'Siêu âm':
        return value.contains('siêu') ||
            value.contains('sieu') ||
            value.contains('ultrasound');
      case 'X Quang':
        return value.contains('x quang') ||
            value.contains('x-quang') ||
            value.contains('xray') ||
            value.contains('x-ray');
      case 'CT Scan':
        return value.contains('ct');
      case 'MRI':
        return value.contains('mri');
      case 'Nội soi':
        return value.contains('nội soi') ||
            value.contains('noi soi') ||
            value.contains('endoscopy');
    }
    return false;
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: Theme.of(context).copyWith(
      textTheme: Theme.of(context).textTheme.apply(fontFamily: 'BeVietnamPro'),
    ),
    child: PatientHomeBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          centerTitle: true,
          toolbarHeight: 112 * MediaQuery.textScalerOf(context).scale(1),
          title: Column(
            children: [
              const Text(
                'Kết quả cận lâm sàng',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                widget.patient.fullName.toUpperCase(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Column(
                children: [
                  _buildFilters(),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: ClinicalResultsYearFilter(
                        year: _year,
                        maxYear: _currentYear,
                        onChanged: (year) => setState(() => _year = year),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final controller = context
                            .watch<TestResultController?>();
                        if (controller == null) {
                          return const _EmptyResults(hasAnyResult: false);
                        }
                        // The controller is shared with PACS. Keep a previous
                        // linked profile's results off-screen until this
                        // patient's query has started.
                        if (controller.patientId != widget.patient.id) {
                          return const AppLoadingWidget(
                            message: 'Đang tải kết quả cận lâm sàng...',
                          );
                        }
                        if (controller.isLoading) {
                          return const AppLoadingWidget(
                            message: 'Đang tải kết quả cận lâm sàng...',
                          );
                        }
                        if (controller.isError) {
                          return _ErrorResults(
                            message:
                                controller.errorMessage ??
                                'Không thể tải kết quả cận lâm sàng.',
                            onRetry: _loadResults,
                          );
                        }
                        final results = _filteredResults(controller.results);
                        if (results.isEmpty) {
                          return _EmptyResults(
                            hasAnyResult: controller.results.isNotEmpty,
                          );
                        }
                        return ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                          itemCount: results.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) => _ResultCard(
                            result: results[index],
                            onTap: () => Navigator.of(context).push<void>(
                              MaterialPageRoute(
                                builder: (_) => TestResultDetailPage(
                                  patient: widget.patient,
                                  result: results[index],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _buildFilters() => ColoredBox(
    color: AppColors.surface,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  '▎ LOẠI CẬN LÂM SÀNG',
                  style: TextStyle(
                    color: AppColors.textOnPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _chooseType,
                icon: const Icon(Icons.list_rounded),
                label: const Text('Chọn loại'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textOnPrimary,
                ),
              ),
            ],
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Row(
            children: [
              for (var index = 0; index < _types.length; index++)
                Padding(
                  key: _typeKeys[index],
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(_types[index]),
                    selected: _selectedType == index,
                    onSelected: (_) => _selectType(index),
                    showCheckmark: false,
                    selectedColor: AppColors.textOnPrimary,
                    backgroundColor: AppColors.primarySoft,
                    side: BorderSide.none,
                    shape: const StadiumBorder(),
                    labelStyle: TextStyle(
                      color: _selectedType == index
                          ? Colors.white
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result, required this.onTap});

  final TestResult result;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(16),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CircleAvatar(
              backgroundColor: AppColors.primarySoft,
              child: Icon(Icons.biotech_outlined, color: AppColors.primaryDark),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.testName.isEmpty
                        ? 'Kết quả chưa có tên'
                        : result.testName,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    result.resultType,
                    style: const TextStyle(
                      color: AppColors.textOnPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    result.resultDescription.isEmpty
                        ? 'Chưa có mô tả kết quả.'
                        : result.resultDescription,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    DateFormat('dd/MM/yyyy').format(result.testDate),
                    style: const TextStyle(
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ],
        ),
      ),
    ),
  );
}

class _EmptyResults extends StatelessWidget {
  const _EmptyResults({required this.hasAnyResult});

  final bool hasAnyResult;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 48),
      child: Column(
        children: [
          const CircleAvatar(
            radius: 52,
            backgroundColor: AppColors.background,
            child: Icon(
              Icons.find_in_page_outlined,
              size: 62,
              color: AppColors.disabled,
            ),
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
            hasAnyResult
                ? 'Không có kết quả phù hợp với bộ lọc năm và loại đã chọn.'
                : 'Bạn chưa có kết quả cận lâm sàng nào.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: AppColors.textSecondary, height: 1.6),
          ),
        ],
      ),
    ),
  );
}

class _ErrorResults extends StatelessWidget {
  const _ErrorResults({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0x1AEF4444),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.error_outline_rounded,
              size: 56,
              color: AppColors.error,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Đã có lỗi xảy ra',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Thử lại'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryDark,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    ),
  );
}
