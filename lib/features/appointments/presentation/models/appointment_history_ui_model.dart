import '../../domain/entities/appointment.dart';

enum AppointmentHistoryTab {
  pending('Chờ xác nhận'),
  paid('Đã thanh toán'),
  received('Đã tiếp nhận'),
  completed('Đã khám'),
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

  AppointmentHistoryTab? get tab => switch (appointment.status) {
    AppointmentStatus.pending => AppointmentHistoryTab.pending,
    AppointmentStatus.completed => AppointmentHistoryTab.completed,
    AppointmentStatus.cancelled => AppointmentHistoryTab.cancelled,
    AppointmentStatus.confirmed =>
      isPaid ? AppointmentHistoryTab.paid : AppointmentHistoryTab.received,
    AppointmentStatus.noShow || AppointmentStatus.unknown => null,
  };
}
