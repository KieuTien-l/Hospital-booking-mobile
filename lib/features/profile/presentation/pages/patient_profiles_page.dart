import 'package:flutter/material.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../home/presentation/widgets/patient_home_background.dart';
import '../../domain/entities/patient.dart';
import '../widgets/patient_profile_card.dart';
import '../widgets/patient_profile_functions_sheet.dart';

class PatientProfilesPage extends StatelessWidget {
  const PatientProfilesPage({
    super.key,
    required this.profiles,
    this.onProfileTap,
    this.isDemo = false,
  });

  final List<Patient> profiles;
  final ValueChanged<Patient>? onProfileTap;
  final bool isDemo;

  void _openProfile(BuildContext context, Patient patient) {
    if (onProfileTap != null) {
      onProfileTap!(patient);
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      constraints: BoxConstraints(
        maxWidth: 680,
        maxHeight: MediaQuery.sizeOf(context).height * .85,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => PatientProfileFunctionsSheet(patient: patient),
    );
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
          title: const Text(
            'Hồ sơ người bệnh',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
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
                            const Icon(
                              Icons.folder_shared_outlined,
                              size: 64,
                              color: AppColors.textOnPrimary,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Bạn chưa có hồ sơ người bệnh.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                        ),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isDemo)
                          const Padding(
                            padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
                            child: Text(
                              'Hồ sơ minh họa — chưa kết nối dữ liệu thật.',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ),
                        Expanded(
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                            itemCount: profiles.length,
                            separatorBuilder: (_, index) =>
                                const SizedBox(height: 14),
                            itemBuilder: (context, index) {
                              final patient = profiles[index];
                              return PatientProfileCard(
                                patient: patient,
                                onTap: () => _openProfile(context, patient),
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
}
