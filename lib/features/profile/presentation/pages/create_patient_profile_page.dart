import 'package:flutter/material.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../home/presentation/widgets/patient_home_background.dart';
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

  void _validate() {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            'Thông tin hợp lệ. Chức năng lưu hồ sơ sẽ được tích hợp sau.',
          ),
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
                  onPressed: _validate,
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
