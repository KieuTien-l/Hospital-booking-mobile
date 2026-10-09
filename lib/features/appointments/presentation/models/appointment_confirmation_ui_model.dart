import 'appointment_time_ui_models.dart';
import '../../../profile/domain/entities/patient.dart';

/// Presentation data only; this does not create an appointment.
class AppointmentConfirmationUiModel {
  const AppointmentConfirmationUiModel({
    required this.specialtyName,
    required this.selection,
    this.patientName,
    this.patient,
    this.fee,
    this.isDemoFee = false,
  });
  final String specialtyName;
  final AppointmentTimeSelection selection;
  final String? patientName;
  final Patient? patient;
  final int? fee;
  final bool isDemoFee;
}

class AppointmentConfirmationResult {
  const AppointmentConfirmationResult({
    required this.information,
    required this.hasHealthInsurance,
    required this.hasPrivateInsurance,
  });
  final AppointmentConfirmationUiModel information;
  final bool hasHealthInsurance;
  final bool hasPrivateInsurance;
}

String appointmentFeeLabel(int? fee) {
  if (fee == null) return 'Chưa có thông tin';
  final digits = fee.toString();
  final formatted = digits.replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+$)'),
    (match) => '${match[1]}.',
  );
  return '$formattedđ';
}
