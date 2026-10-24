import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/state/view_state.dart';
import '../../../../core/themes/app_colors.dart';
import '../../../home/presentation/widgets/patient_home_background.dart';
import '../../domain/entities/specialty.dart';
import '../controllers/specialty_controller.dart';
import '../widgets/specialty_card.dart';

class SpecialtyListPage extends StatefulWidget {
  const SpecialtyListPage({super.key, this.onSpecialtySelected});

  final ValueChanged<Specialty>? onSpecialtySelected;

  @override
  State<SpecialtyListPage> createState() => _SpecialtyListPageState();
}

class _SpecialtyListPageState extends State<SpecialtyListPage> {
  final _search = TextEditingController();
  Timer? _searchDebounce;
  String _queryText = '';
  Specialty? _selected;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<SpecialtyController>().loadSpecialties();
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  /// Vietnamese IMEs emit intermediate composing values (for example `a` then
  /// `â`). Rebuilding the page for an intermediate value can make that value
  /// disappear on some Android keyboards, so wait until composition is done.
  void _onSearchChanged(String value) {
    final composing = _search.value.composing;
    if (composing.isValid && !composing.isCollapsed) return;
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 160), () {
      if (mounted) setState(() => _queryText = value);
    });
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _search.clear();
    setState(() => _queryText = '');
  }

  void _select(Specialty specialty) {
    setState(() => _selected = specialty);
    if (widget.onSpecialtySelected != null) {
      widget.onSpecialtySelected!(specialty);
      return;
    }
    // The page is also usable as a standalone picker. Its caller can await
    // the selected specialty instead of receiving a dead-end placeholder.
    Navigator.of(context).pop(specialty);
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SpecialtyController>();
    final query = normalizeSpecialtySearch(_queryText);
    final matches = controller.specialties
        .where(
          (specialty) =>
              specialty.isActive &&
              normalizeSpecialtySearch(specialty.name).contains(query),
        )
        .toList();
    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: Theme.of(context).textTheme
            .apply(fontFamily: 'BeVietnamPro'),
      ),
      child: PatientHomeBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            title: const Text(
              'Chọn chuyên khoa',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            leading: BackButton(color: AppColors.textOnPrimary),
          ),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                      child: TextField(
                        controller: _search,
                        onChanged: _onSearchChanged,
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          hintText: 'Tìm nhanh chuyên khoa',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _queryText.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'Xóa tìm kiếm',
                                  icon: const Icon(Icons.close),
                                  onPressed: _clearSearch,
                                ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: switch (controller.status) {
                        ViewState.initial || ViewState.loading => const Center(
                          child: CircularProgressIndicator(),
                        ),
                        ViewState.error => _message(
                          'Không thể tải danh sách chuyên khoa. Vui lòng thử lại.',
                          retry: controller.loadSpecialties,
                        ),
                        ViewState.empty => _message(
                          'Chưa có chuyên khoa đang hoạt động.',
                        ),
                        ViewState.success =>
                          matches.isEmpty
                              ? _message(
                                  query.isEmpty
                                      ? 'Chưa có chuyên khoa đang hoạt động.'
                                      : 'Không tìm thấy chuyên khoa phù hợp.',
                                )
                              : ListView.separated(
                                  keyboardDismissBehavior:
                                      ScrollViewKeyboardDismissBehavior.onDrag,
                                  padding: const EdgeInsets.fromLTRB(
                                    20,
                                    0,
                                    20,
                                    24,
                                  ),
                                  itemCount: matches.length,
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(height: 14),
                                  itemBuilder: (_, index) => SpecialtyCard(
                                    key: ValueKey(matches[index].id),
                                    specialty: matches[index],
                                    selected:
                                        _selected?.id == matches[index].id,
                                    onTap: () => _select(matches[index]),
                                  ),
                                ),
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _message(String message, {VoidCallback? retry}) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          if (retry != null) ...[
            const SizedBox(height: 16),
            ElevatedButton(onPressed: retry, child: const Text('Thử lại')),
          ],
        ],
      ),
    ),
  );
}

/// Supports precomposed and combining Vietnamese accents without a dependency.
String normalizeSpecialtySearch(String value) {
  var result = value.toLowerCase().trim();
  const groups = {
    'a': 'àáạảãâầấậẩẫăằắặẳẵ',
    'e': 'èéẹẻẽêềếệểễ',
    'i': 'ìíịỉĩ',
    'o': 'òóọỏõôồốộổỗơờớợởỡ',
    'u': 'ùúụủũưừứựửữ',
    'y': 'ỳýỵỷỹ',
    'd': 'đ',
  };
  for (final entry in groups.entries) {
    for (final rune in entry.value.runes) {
      result = result.replaceAll(String.fromCharCode(rune), entry.key);
    }
  }
  return result
      .replaceAll(RegExp(r'[\u0300-\u036f]'), '')
      .replaceAll(RegExp(r'\s+'), ' ');
}
