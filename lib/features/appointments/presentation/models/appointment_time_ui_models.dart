/// Presentation values; no booking or persistence behavior.
class AppointmentTimeOption {
  const AppointmentTimeOption({
    required this.id,
    required this.label,
    this.available = true,
  });
  final String id;
  final String label;
  final bool available;
}

class AppointmentDoctorOption {
  const AppointmentDoctorOption({
    required this.id,
    required this.name,
    required this.location,
    required this.session,
    required this.schedule,
    this.avatarUrl,
  });
  final String id;
  final String name;
  final String location;
  final String session;
  final String? avatarUrl;
  final Map<DateTime, List<AppointmentTimeOption>> schedule;
}

class AppointmentTimeSelection {
  const AppointmentTimeSelection({
    required this.doctor,
    required this.date,
    required this.slot,
  });
  final AppointmentDoctorOption doctor;
  final DateTime date;
  final AppointmentTimeOption slot;
}

String appointmentDateLabel(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
