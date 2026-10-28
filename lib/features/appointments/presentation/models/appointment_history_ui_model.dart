import '../../domain/entities/appointment.dart';

enum AppointmentHistoryTab {
  pending('Chờ xác nhận'),
  paid('Đã thanh toán'),
  received('Đã tiếp nhận'),
  completed('Đã khám'),
  noShow('Vắng mặt'),
  cancelled('Đã hủy');

  const AppointmentHistoryTab(this.label);
  final String label;
}

/// Display metadata supplied by Presentation; payment is independent of status.
class AppointmentHistoryUiModel {
  const AppointmentHistoryUiModel({
    required this.appointment,
    required this.patientName,
    required this.specialtyName,
    required this.doctorName,
    this.room,
    this.isPaid = false,
  });

  final Appointment appointment;
  final String patientName;
  final String specialtyName;
  final String doctorName;
  final String? room;
  final bool isPaid;

  AppointmentHistoryTab? get tab {
    // Payment is independent of the visit lifecycle. A completed appointment
    // with a successful transaction must still be discoverable in the paid
    // tab rather than disappearing into only the clinical-status tab.
    if (isPaid) return AppointmentHistoryTab.paid;
    return switch (appointment.status) {
    AppointmentStatus.pending => AppointmentHistoryTab.pending,
    AppointmentStatus.completed => AppointmentHistoryTab.completed,
    AppointmentStatus.cancelled => AppointmentHistoryTab.cancelled,
    AppointmentStatus.confirmed =>
      isPaid ? AppointmentHistoryTab.paid : AppointmentHistoryTab.received,
    AppointmentStatus.noShow => AppointmentHistoryTab.noShow,
    AppointmentStatus.unknown => null,
  };
  }
}
