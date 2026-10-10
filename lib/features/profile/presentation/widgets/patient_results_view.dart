import 'package:flutter/material.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../home/presentation/widgets/patient_home_background.dart';
import '../../domain/entities/patient.dart';
import 'clinical_results_year_filter.dart';

/// Presentation-only filters; clinical results await data integration.
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

  @override
  void initState() {
    super.initState();
    _typeKeys = List.generate(_types.length, (_) => GlobalKey());
    final today =
        widget.initialDate ??
        DateTime.now().toUtc().add(const Duration(hours: 7));
    _currentYear = today.year;
    _year = _currentYear;
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
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            28,
                            constraints.maxHeight * .16,
                            28,
                            48,
                          ),
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
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textSecondary,
                                    ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                widget.emptyMessage,
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: AppColors.textSecondary,
                                      height: 1.6,
                                    ),
                              ),
                            ],
                          ),
                        ),
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
}
