import '../../../doctors/domain/entities/work_schedule.dart';
import '../../../doctors/domain/entities/time_slot.dart';
import '../../../appointments/domain/entities/appointment.dart';
import 'doctor_slot_booking.dart';

/// Presentation fixtures only; never persist these schedules or statistics.
abstract final class DoctorHomeDemoData {
  static int _dayOffset(DateTime date, DateTime today) => DateTime.utc(
    date.year,
    date.month,
    date.day,
  ).difference(DateTime.utc(today.year, today.month, today.day)).inDays;

  static List<WorkSchedule> schedules(
    DateTime today, {
    DateTime? selectedDate,
  }) => [
    for (final date in {
      for (final offset in [-1, 0, 1, 2])
        DateTime(today.year, today.month, today.day + offset),
      if (selectedDate != null)
        DateTime(selectedDate.year, selectedDate.month, selectedDate.day),
    })
      for (final morning in [true, false])
        if (date.weekday != DateTime.sunday &&
            (morning || date.weekday != DateTime.saturday))
          WorkSchedule(
            id: 'DEMO-${_dayOffset(date, today) + 2}-${morning ? 'SANG' : 'CHIEU'}',
            doctorId: 'demo-doctor',
            workDate: date,
            startTime: morning ? '06:30' : '13:00',
            endTime: morning ? '11:30' : '16:00',
            status: _dayOffset(date, today) < 0
                ? 'Đã kết thúc'
                : 'Đã phân công',
          ),
  ];

  static List<TimeSlot> timeSlots(List<WorkSchedule> schedules) => [
    for (final schedule in schedules)
      for (
        var index = 0;
        index < (schedule.startTime == '06:30' ? 5 : 3);
        index++
      )
        TimeSlot(
          id: '${schedule.id}-SLOT-$index',
          workScheduleId: schedule.id,
          doctorId: schedule.doctorId,
          startTime: schedule.startTime == '06:30'
              ? '${(6 + index).toString().padLeft(2, '0')}:30'
              : '${13 + index}:00',
          endTime: schedule.startTime == '06:30'
              ? '${(7 + index).toString().padLeft(2, '0')}:30'
              : '${14 + index}:00',
          capacity: schedule.startTime == '06:30' ? 3 : 4,
          bookedCount: schedule.startTime == '06:30'
              ? (index < 4 ? 3 : 0)
              : (index == 1 ? 4 : 2),
          status: TimeSlotStatus.available,
        ),
  ];

  static Map<String, DoctorScheduleCounts> counts(
    List<WorkSchedule> schedules,
  ) => {
    for (final schedule in schedules)
      schedule.id: DoctorScheduleCounts(
        booked: schedule.startTime == '06:30' ? 12 : 8,
        completed: schedule.status == 'Đã kết thúc'
            ? (schedule.startTime == '06:30' ? 12 : 8)
            : schedule.id == 'DEMO-2-SANG'
            ? 7
            : 0,
      ),
  };

  static List<DoctorSlotBooking> bookings(List<WorkSchedule> schedules) {
    const patients = [
      ('Nguyễn Minh Anh', 1992, 'Nữ', 'Khám sức khỏe định kỳ'),
      ('Trần Quốc Bảo', 1985, 'Nam', 'Tái khám theo lịch hẹn'),
      ('Lê Hoàng Phúc', 1978, 'Nam', 'Tư vấn sức khỏe'),
      ('Phạm Ngọc Mai', 1998, 'Nữ', 'Khám sức khỏe tổng quát'),
      ('Võ Thành Đạt', 1989, 'Nam', 'Tái khám theo lịch hẹn'),
      ('Đặng Thu Hà', 1995, 'Nữ', 'Khám sức khỏe định kỳ'),
      ('Bùi Gia Huy', 2001, 'Nam', 'Tư vấn sức khỏe'),
      ('Đỗ Khánh Linh', 1990, 'Nữ', 'Khám sức khỏe tổng quát'),
    ];
    final result = <DoctorSlotBooking>[];
    final statistics = counts(schedules);
    for (final schedule in schedules) {
      var sequence = 0;
      for (final slot in timeSlots([schedule])) {
        for (var index = 0; index < (slot.bookedCount ?? 0); index++) {
          final patient = patients[sequence % patients.length];
          sequence++;
          result.add(
            DoctorSlotBooking(
              appointment: Appointment(
                id: '${slot.id}-LH-${index + 1}',
                patientId: 'DEMO-BN-$sequence',
                doctorId: schedule.doctorId,
                workScheduleId: schedule.id,
                timeSlotId: slot.id,
                appointmentDate: schedule.workDate,
                startTime: slot.startTime,
                endTime: slot.endTime,
                queueNumber: sequence,
                reason: patient.$4,
                status: sequence <= statistics[schedule.id]!.completed
                    ? AppointmentStatus.completed
                    : AppointmentStatus.confirmed,
              ),
              patientName: patient.$1,
              birthYear: patient.$2,
              gender: patient.$3,
            ),
          );
        }
      }
    }
    return result;
  }
}

/// Display-only aggregates, independent of the persisted schedule entity.
class DoctorScheduleCounts {
  const DoctorScheduleCounts({required this.booked, required this.completed});

  final int booked;
  final int completed;
  int get waiting => booked - completed;
}
