import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../../core/widgets/view_state_widgets.dart';
import '../../../home/presentation/widgets/patient_home_background.dart';
import '../../../results/domain/entities/test_result.dart';
import '../../../results/presentation/controllers/test_result_controller.dart';
import '../../domain/entities/patient.dart';
import 'clinical_results_year_filter.dart';
import '../pages/test_result_detail_page.dart';

/// Shared live-results view used by patient-facing result categories such as
/// PACS.  The page intentionally reads the same canonical `KET_QUA_CLS`
/// records as the clinical-results page, then limits them to the requested
/// category in the client. This avoids a composite Firestore index while
/// keeping family-member profiles isolated by `patientId`.
class PatientResultsView extends StatefulWidget {
  const PatientResultsView({
    super.key,
    required this.patient,
    this.initialDate,
    required this.title,
    required this.typeLabel,
    required this.typePickerTitle,
    required this.types,
    required this.emptyTitle,
    required this.emptyMessage,
  });

  final Patient patient;
  final String title;
  final String typeLabel;
  final String typePickerTitle;
  final List<String> types;
  final String emptyTitle;
  final String emptyMessage;
  final DateTime? initialDate;

  @override
  State<PatientResultsView> createState() => _PatientResultsViewState();
}

class _PatientResultsViewState extends State<PatientResultsView> {
  List<String> get _types => widget.types;
  int _type = 0;
  late final int _currentYear;
  late int _year;
  late final List<GlobalKey> _typeKeys;
  String? _loadedPatientId;

  @override
  void initState() {
    super.initState();
    _typeKeys = List.generate(_types.length, (_) => GlobalKey());
    final today =
        widget.initialDate ??
        DateTime.now().toUtc().add(const Duration(hours: 7));
    _currentYear = today.year;
    _year = _currentYear;
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadResults());
  }

  @override
  void didUpdateWidget(covariant PatientResultsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.patient.id != widget.patient.id) {
      _loadedPatientId = null;
      _loadResults();
    }
  }

  void _loadResults() {
    if (!mounted || _loadedPatientId == widget.patient.id) return;
    _loadedPatientId = widget.patient.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _loadedPatientId == widget.patient.id) {
        context.read<TestResultController?>()?.loadResults(widget.patient.id);
      }
    });
  }

  void _selectType(int index) {
    setState(() => _type = index);
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
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      builder: (context) => SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(
                  widget.typePickerTitle,
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                trailing: IconButton(
                  tooltip: 'Đóng',
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              for (var index = 0; index < _types.length; index++)
                ListTile(
                  title: Text(_types[index]),
                  selected: index == _type,
                  selectedColor: AppColors.textOnPrimary,
                  trailing: index == _type
                      ? const Icon(Icons.check, color: AppColors.textOnPrimary)
                      : null,
                  onTap: () => Navigator.of(context).pop(index),
                ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
    if (selected != null && mounted) _selectType(selected);
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
              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                '${widget.patient.fullName.toUpperCase()} (${widget.patient.id})',
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
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Column(
                      children: [
                        ColoredBox(
                          color: AppColors.surface,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        widget.typeLabel,
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
                                        foregroundColor:
                                            AppColors.textOnPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  0,
                                  16,
                                  16,
                                ),
                                child: Row(
                                  children: [
                                    for (
                                      var index = 0;
                                      index < _types.length;
                                      index++
                                    )
                                      Padding(
                                        key: _typeKeys[index],
                                        padding: const EdgeInsets.only(
                                          right: 8,
                                        ),
                                        child: ChoiceChip(
                                          label: Text(_types[index]),
                                          selected: _type == index,
                                          onSelected: (_) => _selectType(index),
                                          showCheckmark: false,
                                          selectedColor:
                                              AppColors.textOnPrimary,
                                          backgroundColor:
                                              AppColors.primarySoft,
                                          side: BorderSide.none,
                                          shape: const StadiumBorder(),
                                          labelStyle: TextStyle(
                                            color: _type == index
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
                        ),
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: ClinicalResultsYearFilter(
                              year: _year,
                              maxYear: _currentYear,
                              onChanged: (year) {
                                if (mounted) setState(() => _year = year);
                              },
                            ),
                          ),
                        ),
                        _buildResults(constraints.maxHeight),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  List<TestResult> _filteredResults(List<TestResult> results) => results
      .where((result) => result.testDate.year == _year)
      .where((result) => _matchesSelectedType(result.resultType))
      .toList(growable: false);

  bool _matchesSelectedType(String source) {
    final value = source.trim().toLowerCase();
    final selectedType = _types[_type];
    return switch (selectedType) {
      'X Quang' =>
        value.contains('x quang') ||
            value.contains('x-quang') ||
            value.contains('xray') ||
            value.contains('x-ray'),
      'CT Scan' =>
        value.contains('ct scan') ||
            RegExp(r'(^|[^a-z])ct([^a-z]|$)').hasMatch(value),
      'MRI' => value.contains('mri'),
      _ => value == selectedType.trim().toLowerCase(),
    };
  }

  Widget _buildResults(double availableHeight) {
    final controller = context.watch<TestResultController?>();
    if (controller == null) return _emptyPanel(availableHeight);
    // TestResultController is shared by the result and PACS routes. Do not
    // show a previous profile's in-memory values while the new query is being
    // scheduled after this frame.
    if (controller.patientId != widget.patient.id) {
      return const SizedBox(
        height: 260,
        child: AppLoadingWidget(message: 'Đang tải hình ảnh chụp...'),
      );
    }
    if (controller.isLoading) {
      return const SizedBox(
        height: 260,
        child: AppLoadingWidget(message: 'Đang tải hình ảnh chụp...'),
      );
    }
    if (controller.isError) {
      return SizedBox(
        height: 320,
        child: AppErrorWidget(
          message: controller.errorMessage ?? 'Không thể tải hình ảnh chụp.',
          onRetry: () => controller.loadResults(widget.patient.id),
        ),
      );
    }

    final results = _filteredResults(controller.results);
    if (results.isEmpty) return _emptyPanel(availableHeight);
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      itemCount: results.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _ImagingResultCard(
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
  }

  Widget _emptyPanel(double availableHeight) => Padding(
    padding: EdgeInsets.fromLTRB(28, availableHeight * .16, 28, 48),
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
          widget.emptyTitle,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          widget.emptyMessage,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: AppColors.textSecondary, height: 1.6),
        ),
      ],
    ),
  );
}

class _ImagingResultCard extends StatelessWidget {
  const _ImagingResultCard({required this.result, required this.onTap});

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
              child: Icon(Icons.image_outlined, color: AppColors.primaryDark),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.testName.isEmpty
                        ? 'Hình ảnh chụp chưa có tên'
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
                        ? 'Chưa có mô tả hình ảnh.'
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
                    '${result.testDate.day.toString().padLeft(2, '0')}/${result.testDate.month.toString().padLeft(2, '0')}/${result.testDate.year}',
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
