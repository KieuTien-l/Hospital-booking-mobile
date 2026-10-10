import 'package:flutter/material.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../home/presentation/widgets/patient_home_background.dart';
import '../../domain/entities/patient.dart';
import '../widgets/health_records_date_filter.dart';
import '../widgets/patient_profile_section_card.dart';
import '../widgets/patient_profile_section_title.dart';

/// Read-only information supplied by the parent route, without data requests.
class PatientProfileInformationPage extends StatelessWidget {
  const PatientProfileInformationPage({super.key, required this.patient});

  final Patient patient;

  String _value(String? value) =>
      value == null || value.trim().isEmpty ? 'Chưa cập nhật' : value.trim();

  String get _birthday => patient.dateOfBirth == null
      ? 'Chưa cập nhật'
      : HealthRecordsDateFilter.format(patient.dateOfBirth!);

  String get _gender => switch (patient.gender?.trim().toUpperCase()) {
    'MALE' || 'NAM' => 'Nam',
    'FEMALE' || 'NỮ' => 'Nữ',
    'OTHER' || 'KHÁC' => 'Khác',
    _ => _value(patient.gender),
  };

  String get _address {
    if (patient.address?.trim().isNotEmpty ?? false) {
      return patient.address!.trim();
    }
    final parts = [patient.ward, patient.district, patient.province]
        .whereType<String>()
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty);
    return _value(parts.join(', '));
  }

  Widget _row(BuildContext context, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 14),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final labelWidget = Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: AppColors.textSecondary),
        );
        final valueWidget = Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        );
        if (constraints.maxWidth < 300 ||
            MediaQuery.textScalerOf(context).scale(1) > 1.3) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [labelWidget, const SizedBox(height: 8), valueWidget],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 4, child: labelWidget),
            const SizedBox(width: 16),
            Expanded(flex: 5, child: valueWidget),
          ],
        );
      },
    ),
  );

  Widget _section(BuildContext context, List<(String, String)> fields) =>
      PatientProfileSectionCard(
        children: [
          for (var index = 0; index < fields.length; index++) ...[
            if (index > 0) const Divider(height: 1),
            _row(context, fields[index].$1, fields[index].$2),
          ],
        ],
      );

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
          title: const Text(
            'Hồ sơ người bệnh',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PatientProfileSectionCard(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const CircleAvatar(
                              radius: 28,
                              backgroundColor: AppColors.textOnPrimary,
                              child: Icon(
                                Icons.person,
                                color: Colors.white,
                                size: 36,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _value(patient.fullName).toUpperCase(),
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textOnPrimary,
                                        ),
                                  ),
                                  const SizedBox(height: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.primarySoft,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '$_gender • $_birthday',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const PatientProfileSectionTitle(
                      title: 'THÔNG TIN CÁ NHÂN',
                      icon: Icons.person_outline,
                    ),
                    const SizedBox(height: 14),
                    _section(context, [
                      ('Ngày sinh', _birthday),
                      ('Giới tính', _gender),
                      (
                        'Quan hệ với chủ tài khoản',
                        _value(patient.relationshipToAccountHolder),
                      ),
                      ('CCCD', _value(patient.nationalId)),
                      ('Quốc gia', _value(patient.country)),
                      ('Nghề nghiệp', _value(patient.occupation)),
                    ]),
                    const SizedBox(height: 24),
                    const PatientProfileSectionTitle(
                      title: 'THÔNG TIN LIÊN HỆ',
                      icon: Icons.contact_phone_outlined,
                    ),
                    const SizedBox(height: 14),
                    _section(context, [
                      ('Số điện thoại', _value(patient.phone)),
                      ('Email', _value(patient.email)),
                      ('Địa chỉ', _address),
                    ]),
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
