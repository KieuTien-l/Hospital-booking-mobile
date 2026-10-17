import '../../../appointments/domain/entities/appointment.dart';

/// Display information joined to an appointment; not a persistence model.
class DoctorSlotBooking {
  const DoctorSlotBooking({
    required this.appointment,
    required this.patientName,
    this.birthYear,
    this.gender,
  });

  final Appointment appointment;
  final String patientName;
  final int? birthYear;
  final String? gender;
}
