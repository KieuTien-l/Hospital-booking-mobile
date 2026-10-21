import 'package:flutter/material.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../home/presentation/widgets/patient_home_background.dart';
import '../../domain/entities/patient.dart';
import '../widgets/patient_profile_card.dart';
import '../widgets/patient_clinical_functions_sheet.dart';
import 'patient_clinical_results_page.dart';
import 'patient_imaging_page.dart';

class PatientClinicalProfilesPage extends StatefulWidget {
  const PatientClinicalProfilesPage({
    super.key,
    required this.profiles,
    this.isDemo = false,
  });

  final List<Patient> profiles;
  final bool isDemo;

  @override
  State<PatientClinicalProfilesPage> createState() =>
      _PatientClinicalProfilesPageState();
}

class _PatientClinicalProfilesPageState
    extends State<PatientClinicalProfilesPage> {
  bool _sheetOpen = false;

  Future<void> _openProfile(BuildContext context, Patient patient) async {
    if (_sheetOpen) return;
    _sheetOpen = true;
    final destination = await showModalBottomSheet<PatientClinicalFunction>(
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
      builder: (_) => PatientClinicalFunctionsSheet(patient: patient),
    );
    _sheetOpen = false;
    if (!context.mounted || destination == null) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => switch (destination) {
          PatientClinicalFunction.results => PatientClinicalResultsPage(
            patient: patient,
          ),
          PatientClinicalFunction.imaging => PatientImagingPage(
            patient: patient,
          ),
        },
      ),
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
            'Kết quả cận lâm sàng',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: widget.profiles.isEmpty
                  ? SingleChildScrollView(
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
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                      itemCount:
                          widget.profiles.length + (widget.isDemo ? 1 : 0),
                      separatorBuilder: (_, _) => const SizedBox(height: 14),
                      itemBuilder: (context, index) {
                        if (widget.isDemo && index == 0) {
                          return const Text(
                            'Hồ sơ minh họa — chưa kết nối dữ liệu thật.',
                            style: TextStyle(color: AppColors.textSecondary),
                          );
                        }
                        final patient =
                            widget.profiles[index - (widget.isDemo ? 1 : 0)];
                        return PatientProfileCard(
                          patient: patient,
                          onTap: () => _openProfile(context, patient),
                        );
                      },
                    ),
            ),
          ),
        ),
      ),
    ),
  );
}
