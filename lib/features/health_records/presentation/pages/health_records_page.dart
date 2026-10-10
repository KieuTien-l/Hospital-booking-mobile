import 'package:flutter/material.dart';

import '../../../profile/presentation/pages/patient_health_records_page.dart';

/// Entry point kept for existing routes. The live screen uses KieuTien's UI.
class HealthRecordsPage extends StatelessWidget {
  const HealthRecordsPage({super.key, this.initialDate});

  /// Allows deterministic UI tests while production uses the current date.
  final DateTime? initialDate;

  @override
  Widget build(BuildContext context) =>
      PatientHealthRecordsPage(initialDate: initialDate);
}
