import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../appointments/domain/entities/appointment.dart';
import '../../../appointments/domain/repositories/appointment_repository.dart';
import '../../../doctors/domain/repositories/doctor_repository.dart';
import '../../../doctors/domain/repositories/time_slot_repository.dart';
import '../../../doctors/domain/repositories/work_schedule_repository.dart';
import '../../domain/entities/doctor_workspace.dart';
import '../../domain/repositories/doctor_workspace_repository.dart';

/// Firebase implementation for the existing mobile backend.
///
/// It only requests the signed-in doctor's profile, schedules, slots, and
/// appointment records. Patient profile documents are never fetched here, so
/// the doctor screen cannot expose fields outside the appointment projection.
class FirestoreDoctorWorkspaceRepository implements DoctorWorkspaceRepository {
  FirestoreDoctorWorkspaceRepository({
    required this.doctorRepository,
    required this.workScheduleRepository,
    required this.timeSlotRepository,
    required this.appointmentRepository,
  });

  final DoctorRepository doctorRepository;
  final WorkScheduleRepository workScheduleRepository;
  final TimeSlotRepository timeSlotRepository;
  final AppointmentRepository appointmentRepository;

  @override
  bool get isDemo => false;

  @override
  bool get canSubmitReports => false;

  @override
  Future<DoctorDayData> loadDay({
    required String userId,
    required DateTime date,
  }) async {
    final day = DateTime(date.year, date.month, date.day);
    try {
      final doctor = await doctorRepository.getDoctorByUserId(userId);
      if (doctor == null ||
          !doctor.isActive ||
          doctor.status.toUpperCase() != 'ACTIVE') {
        throw const DoctorWorkspaceAccessException(
          'Tài khoản chưa có hồ sơ bác sĩ đang hoạt động.',
        );
      }

      final schedules = await workScheduleRepository.getWorkSchedules(
        doctorId: doctor.id,
        workDate: day,
      );
      final slotsBySchedule = await Future.wait(
        schedules.map(
          (schedule) => timeSlotRepository.getTimeSlotsByWorkSchedule(
            schedule.id,
          ),
        ),
      );
      final slots = slotsBySchedule.expand((items) => items).where(
        (slot) => slot.doctorId == doctor.id,
      ).toList(growable: false);
      final scheduleIds = schedules.map((schedule) => schedule.id).toSet();
      final appointments = await appointmentRepository
          .watchAppointmentsByDoctor(doctor.id)
          .first;
      final bookings = appointments
          .where(
            (appointment) =>
                appointment.doctorId == doctor.id &&
                scheduleIds.contains(appointment.workScheduleId) &&
                _sameDay(appointment.appointmentDate, day),
          )
          .map(
            (appointment) => DoctorBooking(
              appointment: appointment,
              patientName: _patientLabel(appointment),
            ),
          )
          .toList(growable: false);

      return DoctorDayData(
        doctor: doctor,
        date: day,
        schedules: schedules,
        slots: slots,
        bookings: bookings,
      );
    } on DoctorWorkspaceAccessException {
      rethrow;
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied' || error.code == 'unauthenticated') {
        throw const DoctorWorkspaceAccessException(
          'Bạn không có quyền xem dữ liệu bác sĩ này.',
        );
      }
      throw StateError('Không thể tải dữ liệu bác sĩ. Vui lòng thử lại.');
    }
  }

  static bool _sameDay(DateTime? value, DateTime day) =>
      value != null &&
      value.year == day.year &&
      value.month == day.month &&
      value.day == day.day;

  static String _patientLabel(Appointment appointment) {
    final queue = appointment.queueNumber;
    return queue == null ? 'Bệnh nhân đã đặt lịch' : 'Bệnh nhân #$queue';
  }

  @override
  Future<List<DoctorReport>> loadReports({required String userId}) async =>
      const [];

  @override
  Future<DoctorReport> submitReport({
    required String userId,
    required DoctorReportDraft draft,
  }) => Future.error(
    StateError('Chức năng gửi báo cáo chưa được kết nối với Firebase.'),
  );
}
