import '../../../profile/presentation/models/patient_profiles_demo_data.dart';
import 'appointment_confirmation_ui_model.dart';
import 'appointment_time_demo_data.dart';
import 'appointment_time_ui_models.dart';
import 'payment_ui_model.dart';

abstract final class PaymentDemoData {
  static List<PaymentUiModel> get transactions {
    final date = DateTime(2026, 10, 11);
    final doctor = AppointmentTimeDemoData.doctors(date).first;
    final items = [
      AppointmentConfirmationResult(
        information: AppointmentConfirmationUiModel(
          specialtyName: 'Khám nội tổng quát',
          patient: PatientProfilesDemoData.profiles.first,
          selection: AppointmentTimeSelection(
            doctor: doctor,
            date: date,
            slot: doctor.schedule[date]!.last,
          ),
          fee: 150000,
          isDemoFee: true,
        ),
        hasHealthInsurance: false,
        hasPrivateInsurance: false,
      ),
    ];
    return [
      for (final status in PaymentStatus.values)
        PaymentUiModel(
          items: items,
          method: PaymentMethod.values[status.index],
          status: status,
          transactionId: 'DEMO-TT00${status.index + 1}',
          timestamp: DateTime(2026, 10, 11, 9, 30),
          isDemo: true,
        ),
    ];
  }
}
