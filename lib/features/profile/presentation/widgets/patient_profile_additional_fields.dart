import 'package:flutter/material.dart';

import '../../../../core/themes/app_colors.dart';
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
          _input(
            'Quốc gia',
            'country',
            initialValue: 'Việt Nam',
            hint: 'Nhập quốc gia',
            validator: (value) =>
                PatientProfileValidators.address(value, 'Quốc gia'),
            onSaved: (value) => widget.draft?.country = value?.trim() ?? '',
          ),
          _input(
            'Tỉnh / Thành phố',
            'province',
            hint: 'Nhập tỉnh hoặc thành phố',
            validator: (value) =>
                PatientProfileValidators.address(value, 'Tỉnh / Thành phố'),
            onSaved: (value) => widget.draft?.province = value?.trim() ?? '',
          ),
          _input(
            'Phường / Xã',
            'ward',
            hint: 'Nhập phường hoặc xã',
            validator: (value) =>
                PatientProfileValidators.address(value, 'Phường / Xã'),
            onSaved: (value) => widget.draft?.ward = value?.trim() ?? '',
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
