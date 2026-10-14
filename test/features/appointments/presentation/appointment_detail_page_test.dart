import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:flutter_application_4/features/appointments/domain/entities/appointment.dart';
import 'package:flutter_application_4/features/appointments/domain/repositories/booking_repository.dart';
import 'package:flutter_application_4/features/appointments/domain/usecases/book_appointment.dart';
import 'package:flutter_application_4/features/appointments/presentation/controllers/appointment_controller.dart';
import 'package:flutter_application_4/features/appointments/presentation/models/appointment_history_ui_model.dart';
import 'package:flutter_application_4/features/appointments/presentation/pages/appointment_detail_page.dart';

class _CancellationBookingRepository implements BookingRepository {
  String? cancelledAppointmentId;
  String? cancellationReason;

  @override
  Future<Appointment> cancelAppointment(
    String appointmentId,
    String reason,
  ) async {
    cancelledAppointmentId = appointmentId;
    cancellationReason = reason;
    return Appointment(
      id: appointmentId,
      patientId: 'patient-1',
      doctorId: 'doctor-1',
      workScheduleId: 'schedule-1',
      timeSlotId: 'slot-1',
      status: AppointmentStatus.cancelled,
      cancellationReason: reason,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('Cancelling closes the reason dialog without controller errors', (
    tester,
  ) async {
    final repository = _CancellationBookingRepository();
    final controller = AppointmentController(
      bookingRepository: repository,
      bookAppointmentUseCase: BookAppointment(repository),
    );
    addTearDown(controller.dispose);
    final appointment = Appointment(
      id: 'appointment-1',
      patientId: 'patient-1',
      doctorId: 'doctor-1',
      workScheduleId: 'schedule-1',
      timeSlotId: 'slot-1',
      specialtyId: 'specialty-1',
      appointmentDate: DateTime(2026, 10, 20),
      startTime: '08:00',
      endTime: '08:30',
      status: AppointmentStatus.pending,
    );

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: controller,
        child: MaterialApp(
          home: AppointmentDetailPage(
            item: AppointmentHistoryUiModel(
              appointment: appointment,
              patientName: 'Nguyễn An',
              doctorName: 'BS. Phạm Ngọc Mai',
              specialtyName: 'Khoa Nội Tim mạch',
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('cancel-appointment')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Không sắp xếp được thời gian');
    await tester.tap(find.widgetWithText(FilledButton, 'Hủy lịch').last);
    await tester.pumpAndSettle();

    expect(repository.cancelledAppointmentId, appointment.id);
    expect(repository.cancellationReason, 'Không sắp xếp được thời gian');
    expect(tester.takeException(), isNull);
  });
}
