import 'package:flutter/material.dart';

import '../../../../core/themes/app_colors.dart';
import '../validators/patient_profile_validators.dart';
import 'patient_profile_additional_fields.dart';
import 'patient_profile_section_card.dart';
import 'patient_profile_section_title.dart';

class PatientProfileForm extends StatefulWidget {
  const PatientProfileForm({
    super.key,
    required this.formKey,
    required this.ethnicities,
    required this.occupations,
    required this.relationships,
  });

  final GlobalKey<FormState> formKey;
  final List<String> ethnicities;
  final List<String> occupations;
  final List<String> relationships;

  @override
  State<PatientProfileForm> createState() => _PatientProfileFormState();
}

class _PatientProfileFormState extends State<PatientProfileForm> {
  final _dateText = TextEditingController();
  DateTime? _birthDate;

  @override
  void dispose() {
    _dateText.dispose();
    super.dispose();
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text.rich(
      TextSpan(
        children: [
          TextSpan(text: text),
          const TextSpan(
            text: ' *',
            style: TextStyle(color: AppColors.error),
          ),
        ],
      ),
    ),
  );

  Widget _dropdown(String label, List<String> options) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _label(label),
      DropdownButtonFormField<String>(
        key: ValueKey(label),
        isExpanded: true,
        decoration: const InputDecoration(
          hintText: 'Chọn...',
          errorMaxLines: 3,
        ),
        items: options
            .map((value) => DropdownMenuItem(value: value, child: Text(value)))
            .toList(),
        onChanged: (_) {},
        autovalidateMode: AutovalidateMode.onUserInteraction,
        validator: (value) =>
            PatientProfileValidators.selection(value, label, options),
      ),
    ],
  );

  Future<void> _pickDate(FormFieldState<String> field) async {
    final now = DateUtils.dateOnly(DateTime.now());
    final date = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'Chọn ngày sinh',
      cancelText: 'Hủy',
      confirmText: 'Chọn',
    );
    if (date == null || !mounted) return;
    _birthDate = date;
    _dateText.text =
        '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    field.didChange(_dateText.text);
  }

  @override
  Widget build(BuildContext context) => Form(
    key: widget.formKey,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PatientProfileSectionCard(
          children: [
            const PatientProfileSectionTitle(
              title: 'Thông tin bệnh nhân',
              icon: Icons.person_outline_rounded,
            ),
            const SizedBox(height: 8),
            const Text(
              'Nhập thông tin theo CCCD, hộ chiếu hoặc giấy khai sinh.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            _label('Họ và chữ lót'),
            TextFormField(
              key: const ValueKey('familyName'),
              decoration: const InputDecoration(
                hintText: 'VD: Nguyễn Văn',
                helperText: 'Không ghi tên',
                errorMaxLines: 3,
              ),
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              validator: (value) =>
                  PatientProfileValidators.name(value, 'Họ và chữ lót'),
            ),
            const SizedBox(height: 20),
            _label('Tên bệnh nhân'),
            TextFormField(
              key: const ValueKey('givenName'),
              decoration: const InputDecoration(
                hintText: 'VD: An',
                helperText: 'Không ghi họ hoặc chữ lót',
                errorMaxLines: 3,
              ),
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              validator: (value) =>
                  PatientProfileValidators.name(value, 'Tên bệnh nhân'),
            ),
            const SizedBox(height: 20),
            _label('Ngày sinh'),
            FormField<String>(
              autovalidateMode: AutovalidateMode.onUserInteraction,
              validator: (_) {
                if (_birthDate == null) return 'Vui lòng chọn ngày sinh.';
                if (_birthDate!.isAfter(DateUtils.dateOnly(DateTime.now()))) {
                  return 'Ngày sinh không được lớn hơn ngày hiện tại.';
                }
                return null;
              },
              builder: (field) => TextField(
                controller: _dateText,
                readOnly: true,
                onTap: () => _pickDate(field),
                decoration: InputDecoration(
                  hintText: 'DD / MM / YYYY',
                  errorText: field.errorText,
                  errorMaxLines: 3,
                  suffixIcon: IconButton(
                    tooltip: 'Chọn ngày sinh',
                    onPressed: () => _pickDate(field),
                    icon: const Icon(Icons.calendar_today_outlined),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            _dropdown('Dân tộc', widget.ethnicities),
            const SizedBox(height: 20),
            _label('Giới tính'),
            FormField<String>(
              autovalidateMode: AutovalidateMode.onUserInteraction,
              validator: (value) => PatientProfileValidators.selection(
                value,
                'giới tính',
                const ['Nam', 'Nữ'],
              ),
              builder: (field) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RadioGroup<String>(
                    groupValue: field.value,
                    onChanged: field.didChange,
                    child: Row(
                      children: [
                        for (final gender in const ['Nam', 'Nữ'])
                          Expanded(
                            child: RadioListTile<String>(
                              value: gender,
                              title: Text(gender),
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              activeColor: AppColors.textOnPrimary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (field.hasError)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        field.errorText!,
                        style: const TextStyle(
                          color: AppColors.error,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _dropdown('Nghề nghiệp', widget.occupations),
            const SizedBox(height: 20),
            _dropdown('Quan hệ với chủ tài khoản', widget.relationships),
          ],
        ),
        const SizedBox(height: 20),
        const PatientProfileAdditionalFields(),
      ],
    ),
  );
}
