import 'package:flutter/material.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../home/presentation/widgets/patient_home_background.dart';
import '../../domain/entities/patient.dart';
import '../widgets/patient_profile_card.dart';
import 'create_patient_profile_page.dart';

class SelectPatientProfilePage extends StatelessWidget {
  const SelectPatientProfilePage({
    super.key,
    required this.profiles,
    required this.onProfileSelected,
    required this.onHome,
    this.isDemo = false,
  });

  final List<Patient> profiles;
  final ValueChanged<Patient> onProfileSelected;
  final VoidCallback onHome;
  final bool isDemo;

  void _create(BuildContext context) => Navigator.of(context).push<void>(
    MaterialPageRoute(builder: (_) => const CreatePatientProfilePage()),
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
            'Đặt khám',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          actions: [
            IconButton(
              tooltip: 'Về trang chủ',
              onPressed: onHome,
              icon: const Icon(
                Icons.home_outlined,
                color: AppColors.textOnPrimary,
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: profiles.isEmpty
                  ? Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Chọn hồ sơ',
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Bạn chưa có hồ sơ khám bệnh. Hãy tạo hồ sơ để tiếp tục đặt khám.',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            FilledButton(
                              onPressed: () => _create(context),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.primaryDark,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Tạo hồ sơ khám bệnh'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                      children: [
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            Text(
                              'Chọn hồ sơ',
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            FilledButton.icon(
                              onPressed: () => _create(context),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.primaryDark,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              icon: const Icon(Icons.person_add_alt_1),
                              label: const Text('Thêm mới hồ sơ'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (isDemo)
                          const Text(
                            'Hồ sơ minh họa — chưa kết nối dữ liệu thật.',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        const SizedBox(height: 20),
                        for (final patient in profiles)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: PatientProfileCard(
                              patient: patient,
                              onTap: () => onProfileSelected(patient),
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
}
