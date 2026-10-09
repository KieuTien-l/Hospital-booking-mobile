import 'appointment_time_ui_models.dart';

/// Relative offsets are demo fixtures, never a doctor's real work schedule.
abstract final class AppointmentTimeDemoData {
  static List<AppointmentDoctorOption> doctors(DateTime initialDate) {
    final date = DateTime(initialDate.year, initialDate.month, initialDate.day);
    final dates = [
      for (final offset in [0, 7, 14, 21, 28]) date.add(Duration(days: offset)),
    ];
    return [
      AppointmentDoctorOption(
        id: 'demo-morning',
        name: 'BSCKII. Nguyễn Văn A',
        location: 'Phòng 66 - Lầu 1 Khu B',
        session: 'Buổi sáng',
        schedule: {
          for (final day in dates)
            day: const [
              AppointmentTimeOption(
                id: 'morning-1',
                label: '06:30 - 07:30',
                available: false,
              ),
              AppointmentTimeOption(
                id: 'morning-2',
                label: '07:30 - 08:30',
                available: false,
              ),
              AppointmentTimeOption(
                id: 'morning-3',
                label: '08:30 - 09:30',
                available: false,
              ),
              AppointmentTimeOption(
                id: 'morning-4',
                label: '09:30 - 10:30',
                available: false,
              ),
              AppointmentTimeOption(id: 'morning-5', label: '10:30 - 11:30'),
            ],
        },
      ),
      AppointmentDoctorOption(
        id: 'demo-afternoon',
        name: 'ThS.BS. Trần Thị B',
        location: 'Phòng 66 - Lầu 1 Khu B',
        session: 'Buổi chiều',
        schedule: {
          for (var i = 0; i < dates.length; i++)
            dates[i]: i == 2
                ? const []
                : const [
                    AppointmentTimeOption(
                      id: 'afternoon-1',
                      label: '13:00 - 14:00',
                    ),
                    AppointmentTimeOption(
                      id: 'afternoon-2',
                      label: '14:00 - 15:00',
                      available: false,
                    ),
                    AppointmentTimeOption(
                      id: 'afternoon-3',
                      label: '15:00 - 16:00',
                    ),
                  ],
        },
      ),
    ];
  }
}
