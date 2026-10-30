import 'package:flutter/material.dart';

import '../../../../core/themes/app_colors.dart';
import '../../data/vietnam_administrative_division.dart';
import '../models/patient_profile_form_draft.dart';
import '../validators/patient_profile_validators.dart';
import 'patient_profile_section_card.dart';
import 'patient_profile_section_title.dart';

/// UI-only fields; no writes to a repository or changes to the patient entity.
class PatientProfileAdditionalFields extends StatefulWidget {
  const PatientProfileAdditionalFields({super.key, this.draft});

  final PatientProfileFormDraft? draft;

  @override
  State<PatientProfileAdditionalFields> createState() =>
      _PatientProfileAdditionalFieldsState();
}

class _PatientProfileAdditionalFieldsState
    extends State<PatientProfileAdditionalFields> {
  final _identityValues = <String, String>{};
  final _divisionService = VietnamAdministrativeDivisionService();
  VietnamAdministrativeDivision? _province;
  VietnamAdministrativeDivision? _ward;

  Future<void> _pickProvince() async {
    final selected = await _pickDivision(
      title: 'Chọn Tỉnh / Thành phố',
      loader: _divisionService.provinces,
    );
    if (!mounted || selected == null) return;
    setState(() {
      _province = selected;
      _ward = null;
    });
  }

  Future<void> _pickWard() async {
    final province = _province;
    if (province == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn Tỉnh / Thành phố trước.')),
      );
      return;
    }
    final selected = await _pickDivision(
      title: 'Chọn Phường / Xã',
      loader: () => _divisionService.wards(province.code),
    );
    if (!mounted || selected == null) return;
    setState(() => _ward = selected);
  }

  Future<VietnamAdministrativeDivision?> _pickDivision({
    required String title,
    required Future<List<VietnamAdministrativeDivision>> Function() loader,
  }) => showModalBottomSheet<VietnamAdministrativeDivision>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) =>
        _DivisionPickerSheet(title: title, loader: loader),
  );

  Widget _divisionField({
    required String label,
    required String fieldKey,
    required String hint,
    required String value,
    required VoidCallback? onTap,
    required FormFieldSetter<String> onSaved,
  }) => Padding(
    padding: const EdgeInsets.only(top: 16),
    child: FormField<String>(
      // Re-create this read-only field when the chosen value changes so its
      // FormField validation state follows the visible selection.
      key: ValueKey('$fieldKey-$value'),
      initialValue: value,
      validator: (candidate) =>
          PatientProfileValidators.address(candidate, label),
      onSaved: onSaved,
      builder: (field) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label),
          const SizedBox(height: 8),
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: InputDecorator(
              isEmpty: value.isEmpty,
              decoration: InputDecoration(
                errorText: field.errorText,
                suffixIcon: onTap == null
                    ? null
                    : const Icon(Icons.keyboard_arrow_down_rounded),
              ),
              child: Text(
                value.isEmpty ? hint : value,
                style: TextStyle(
                  color: value.isEmpty
                      ? AppColors.textSecondary
                      : AppColors.textPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _input(
    String label,
    String key, {
    String? hint,
    String? initialValue,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    ValueChanged<String>? onChanged,
    FormFieldSetter<String>? onSaved,
  }) => Padding(
    padding: const EdgeInsets.only(top: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        const SizedBox(height: 8),
        TextFormField(
          key: ValueKey(key),
          initialValue: initialValue,
          keyboardType: keyboardType,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(hintText: hint, errorMaxLines: 3),
          autovalidateMode: AutovalidateMode.onUserInteraction,
          validator: validator,
          onChanged: onChanged,
          onSaved: onSaved,
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      PatientProfileSectionCard(
        children: [
          const PatientProfileSectionTitle(
            title: 'Liên hệ',
            icon: Icons.contact_phone_outlined,
          ),
          _input(
            'Số điện thoại',
            'contactPhone',
            hint: 'Nhập số điện thoại',
            keyboardType: TextInputType.phone,
            validator: PatientProfileValidators.phone,
            onSaved: (value) => widget.draft?.phone = value?.trim() ?? '',
          ),
          _input(
            'Email',
            'contactEmail',
            hint: 'Nhập email',
            keyboardType: TextInputType.emailAddress,
            validator: PatientProfileValidators.email,
            onSaved: (value) => widget.draft?.email = value?.trim() ?? '',
          ),
        ],
      ),
      const SizedBox(height: 20),
      PatientProfileSectionCard(
        children: [
          const PatientProfileSectionTitle(
            title: 'Giấy tờ định danh',
            icon: Icons.badge_outlined,
          ),
          const SizedBox(height: 8),
          const Text(
            'Nhập ít nhất một trong ba loại giấy tờ bên dưới.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          FormField<String>(
            key: const ValueKey('identityDocuments'),
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: (_) =>
                _identityValues.values.any((value) => value.trim().isNotEmpty)
                ? null
                : 'Vui lòng nhập CCCD, số định danh cá nhân hoặc hộ chiếu.',
            builder: (field) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final entry in const {
                  'nationalId': 'CCCD',
                  'personalId': 'Số định danh cá nhân',
                  'passport': 'Hộ chiếu',
                }.entries)
                  _input(
                    entry.value,
                    entry.key,
                    hint: 'Nhập ${entry.value.toLowerCase()}',
                    validator: (value) =>
                        PatientProfileValidators.document(value, entry.key),
                    keyboardType: entry.key == 'passport'
                        ? TextInputType.text
                        : TextInputType.number,
                    onChanged: (value) {
                      _identityValues[entry.key] = value;
                      field.didChange(value);
                    },
                    onSaved: (value) {
                      final normalized = value?.trim() ?? '';
                      switch (entry.key) {
                        case 'nationalId':
                          widget.draft?.nationalId = normalized;
                          break;
                        case 'personalId':
                          widget.draft?.personalId = normalized;
                          break;
                        case 'passport':
                          widget.draft?.passport = normalized;
                          break;
                      }
                    },
                  ),
                if (field.hasError)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      field.errorText!,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: AppColors.error),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 20),
      PatientProfileSectionCard(
        children: [
          const PatientProfileSectionTitle(
            title: 'Địa chỉ',
            icon: Icons.location_on_outlined,
          ),
          _divisionField(
            label: 'Quốc gia',
            fieldKey: 'country',
            hint: 'Việt Nam',
            value: 'Việt Nam',
            onTap: null,
            onSaved: (_) => widget.draft?.country = 'Việt Nam',
          ),
          _divisionField(
            label: 'Tỉnh / Thành phố',
            fieldKey: 'province',
            hint: 'Chọn tỉnh hoặc thành phố',
            value: _province?.name ?? '',
            onTap: _pickProvince,
            onSaved: (_) => widget.draft?.province = _province?.name ?? '',
          ),
          _divisionField(
            label: 'Phường / Xã',
            fieldKey: 'ward',
            hint: _province == null
                ? 'Chọn Tỉnh / Thành phố trước'
                : 'Chọn phường hoặc xã',
            value: _ward?.name ?? '',
            onTap: _pickWard,
            onSaved: (_) => widget.draft?.ward = _ward?.name ?? '',
          ),
          _input(
            'Số nhà / Đường / Khu phố / Ấp',
            'streetAddress',
            hint: 'Nhập địa chỉ cụ thể',
            validator: (value) => PatientProfileValidators.address(
              value,
              'Địa chỉ',
              maxLength: 255,
            ),
            onSaved: (value) =>
                widget.draft?.streetAddress = value?.trim() ?? '',
          ),
        ],
      ),
    ],
  );
}

class _DivisionPickerSheet extends StatefulWidget {
  const _DivisionPickerSheet({required this.title, required this.loader});

  final String title;
  final Future<List<VietnamAdministrativeDivision>> Function() loader;

  @override
  State<_DivisionPickerSheet> createState() => _DivisionPickerSheetState();
}

class _DivisionPickerSheetState extends State<_DivisionPickerSheet> {
  late final Future<List<VietnamAdministrativeDivision>> _items = widget
      .loader();
  String _query = '';

  @override
  Widget build(BuildContext context) => SafeArea(
    child: FractionallySizedBox(
      heightFactor: .82,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        child: Column(
          children: [
            Text(
              widget.title,
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            TextField(
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Tìm kiếm',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) => setState(() => _query = value.trim()),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: FutureBuilder<List<VietnamAdministrativeDivision>>(
                future: _items,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return const Center(
                      child: Text(
                        'Không tải được danh mục. Vui lòng kiểm tra mạng và thử lại.',
                        textAlign: TextAlign.center,
                      ),
                    );
                  }
                  final needle = _query.toLowerCase();
                  final values = snapshot.data!
                      .where((item) => item.name.toLowerCase().contains(needle))
                      .toList(growable: false);
                  if (values.isEmpty) {
                    return const Center(
                      child: Text('Không có kết quả phù hợp.'),
                    );
                  }
                  return ListView.separated(
                    itemCount: values.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, index) => ListTile(
                      title: Text(values[index].name),
                      onTap: () => Navigator.pop(context, values[index]),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
