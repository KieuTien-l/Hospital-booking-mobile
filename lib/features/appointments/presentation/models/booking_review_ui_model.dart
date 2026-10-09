import 'appointment_confirmation_ui_model.dart';

/// Only presentation fees are summed. Missing or invalid prices stay unknown.
String bookingReviewTotalLabel(List<AppointmentConfirmationResult> items) {
  if (items.isEmpty) return appointmentFeeLabel(0);
  if (items.any(
    (item) => item.information.fee == null || item.information.fee! < 0,
  )) {
    return 'Chưa có thông tin giá';
  }
  return appointmentFeeLabel(
    items.fold<int>(0, (sum, item) => sum + item.information.fee!),
  );
}

bool bookingReviewItemIsValid(AppointmentConfirmationResult item) =>
    item.information.specialtyName.trim().isNotEmpty &&
    item.information.selection.doctor.name.trim().isNotEmpty &&
    item.information.selection.slot.label.trim().isNotEmpty &&
    item.information.selection.slot.available;
