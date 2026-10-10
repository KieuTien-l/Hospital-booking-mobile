import '../../domain/entities/appointment.dart';
import 'appointment_history_ui_model.dart';

/// Fixtures never represent the signed-in account's appointments.
abstract final class AppointmentHistoryDemoData {
  static List<AppointmentHistoryUiModel> get items => [
    for (var index = 0; index < 4; index++)
      AppointmentHistoryUiModel(
        appointment: Appointment(
          id: 'DEMO-AP00${index + 1}',
          patientId: 'DEMO-BN001',
          doctorId: 'demo-doctor',
          workScheduleId: 'demo-schedule',
          timeSlotId: 'demo-slot',
          specialtyId: index.isEven ? 'demo-general' : 'demo-skin',
          appointmentDate: DateTime(2026, 10, 15 + index),
          startTime: '08:30',
          endTime: '09:30',
          status: [
            AppointmentStatus.confirmed,
            AppointmentStatus.confirmed,
            AppointmentStatus.completed,
            AppointmentStatus.cancelled,
          ][index],
        ),
        patientName: 'Nguyễn Văn An',
        specialtyName: index.isEven ? 'Nội tổng quát' : 'Da liễu',
        doctorName: 'BS. Trần Minh Bình',
        room: 'Phòng khám minh họa 01',
        isPaid: index == 0,
      ),
  ];
}
