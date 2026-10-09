import 'package:flutter/material.dart';

import '../../../../core/themes/app_colors.dart';
import '../../../home/presentation/widgets/patient_home_background.dart';
import '../models/appointment_confirmation_ui_model.dart';
import '../widgets/appointment_summary_card.dart';
import '../widgets/insurance_choice_card.dart';
import '../widgets/appointment_confirmation_actions.dart';
import 'booking_review_page.dart';

class ConfirmAppointmentPage extends StatefulWidget {
  const ConfirmAppointmentPage({
    super.key,
    required this.information,
    this.onContinue,
    this.onSubmitBooking,
  });
  final AppointmentConfirmationUiModel information;
  final ValueChanged<AppointmentConfirmationResult>? onContinue;
  final BookingReviewSubmitter? onSubmitBooking;

  @override
  State<ConfirmAppointmentPage> createState() => _ConfirmAppointmentPageState();
}

class _ConfirmAppointmentPageState extends State<ConfirmAppointmentPage> {
  bool? _healthInsurance;
  bool? _privateInsurance;

  void _message(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

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
          foregroundColor: AppColors.textOnPrimary,
          title: const Text(
            'Thông tin đặt khám',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        body: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  AppointmentSummaryCard(information: widget.information),
                  const SizedBox(height: 16),
                  InsuranceChoiceCard(
                    title: 'Bảo hiểm y tế',
                    groupId: 'health',
                    value: _healthInsurance,
                    onChanged: (value) =>
                        setState(() => _healthInsurance = value),
                  ),
                  const SizedBox(height: 12),
                  InsuranceChoiceCard(
                    title: 'Bảo hiểm tư nhân',
                    description: 'Bảo lãnh viện phí tại bệnh viện',
                    groupId: 'private',
                    value: _privateInsurance,
                    onChanged: (value) =>
                        setState(() => _privateInsurance = value),
                  ),
                  const SizedBox(height: 20),
                  AppointmentConfirmationActions(
                    information: widget.information,
                    onAddSpecialty: () => _message(
                      'Chức năng thêm chuyên khoa chưa được hỗ trợ.',
                    ),
                    onContinue:
                        _healthInsurance == null || _privateInsurance == null
                        ? null
                        : () {
                            final result = AppointmentConfirmationResult(
                              information: widget.information,
                              hasHealthInsurance: _healthInsurance!,
                              hasPrivateInsurance: _privateInsurance!,
                            );
                            if (widget.onContinue != null) {
                              widget.onContinue!(result);
                            } else {
                              Navigator.of(context).push<void>(
                                MaterialPageRoute(
                                  builder: (_) => BookingReviewPage(
                                    items: [result],
                                    onSubmitBooking: widget.onSubmitBooking,
                                  ),
                                ),
                              );
                            }
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
