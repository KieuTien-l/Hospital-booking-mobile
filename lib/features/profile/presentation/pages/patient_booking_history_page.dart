import 'package:flutter/material.dart';

import '../../../appointments/presentation/pages/appointment_history_page.dart';
import '../../../appointments/presentation/models/appointment_history_ui_model.dart';
import '../../domain/entities/patient.dart';

/// Keeps profile-scoped navigation while sharing the history screen.
class PatientBookingHistoryPage extends StatelessWidget {
  const PatientBookingHistoryPage({
    super.key,
    required this.patient,
    this.initialDate,
    this.items = const [],
    this.isDemo = false,
  });
  final Patient patient;
  final DateTime? initialDate;
  final List<AppointmentHistoryUiModel> items;
  final bool isDemo;

  @override
  Widget build(BuildContext context) => AppointmentHistoryPage(
    patientId: patient.id,
    items: items,
    isDemo: isDemo,
    initialDate: initialDate,
  );
}
