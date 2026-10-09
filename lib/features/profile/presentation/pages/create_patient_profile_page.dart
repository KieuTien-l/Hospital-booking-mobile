import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../home/presentation/widgets/patient_home_background.dart';
import '../../domain/entities/patient.dart';
import '../controllers/patient_profile_controller.dart';
import '../models/patient_profile_form_draft.dart';
import '../models/patient_profile_demo_data.dart';
import '../widgets/patient_profile_form.dart';

class CreatePatientProfilePage extends StatefulWidget {
  const CreatePatientProfilePage({
    super.key,
    this.ethnicities = PatientProfileDemoData.ethnicities,
    this.occupations = PatientProfileDemoData.occupations,
    this.relationships = PatientProfileDemoData.relationships,
  });

  final List<String> ethnicities;
  final List<String> occupations;
  final List<String> relationships;

  @override
  State<CreatePatientProfilePage> createState() =>
      _CreatePatientProfilePageState();
}

class _CreatePatientProfilePageState extends State<CreatePatientProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _draft = PatientProfileFormDraft();

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    final user = context.read<AuthController?>()?.currentUser;
    final controller = context.read<PatientProfileController?>();
    if (user == null || controller == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng đăng nhập để lưu hồ sơ.')),
      );
      return;
    }

    final current = controller.patient;
    final patient = Patient(
      id: current?.id ?? '',
      authUserId: user.id,
      fullName: _draft.fullName,
      phone: _draft.phone.isEmpty ? user.phone : _draft.phone,
      email: _draft.email.isEmpty ? user.email : _draft.email,
      isActive: current?.isActive ?? true,
      dateOfBirth: _draft.dateOfBirth,
      gender: _draft.gender,
      address: _draft.address,
      avatarUrl: current?.avatarUrl,
      insuranceNumber: current?.insuranceNumber,
      ethnicity: _draft.ethnicity,
      occupation: _draft.occupation,
      ward: _draft.ward.trim().isEmpty ? null : _draft.ward.trim(),
      district: current?.district,
      province: _draft.province.trim().isEmpty ? null : _draft.province.trim(),
      country: _draft.country.trim().isEmpty ? null : _draft.country.trim(),
      nationalId: _draft.identityDocument,
      relationshipToAccountHolder: _draft.relationshipToAccountHolder,
      status: current?.status ?? 'ACTIVE',
    );
    final error = controller.validateProfile(patient);
    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    final saved = await controller.updatePatient(patient);
    if (!mounted) return;
    if (saved == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(controller.errorMessage ?? 'Không thể lưu hồ sơ.'),
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          current == null
              ? 'Tạo hồ sơ thành công!'
              : 'Cập nhật hồ sơ thành công!',
        ),
      ),
    );
    Navigator.of(context).pop();
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
            'Tạo hồ sơ khám bệnh',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.all(20),
                child: PatientProfileForm(
                  formKey: _formKey,
                  ethnicities: widget.ethnicities,
                  occupations: widget.occupations,
                  relationships: widget.relationships,
                  draft: _draft,
                ),
              ),
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryDark,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 52),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'TẠO HỒ SƠ KHÁM BỆNH',
                    textAlign: TextAlign.center,
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
