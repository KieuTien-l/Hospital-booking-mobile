import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../appointments/domain/entities/appointment.dart';
import '../../../appointments/domain/repositories/appointment_repository.dart';
import '../../../doctors/domain/repositories/doctor_repository.dart';
import '../../../doctors/data/models/doctor_model.dart';
import '../../../doctors/domain/repositories/time_slot_repository.dart';
import '../../../doctors/domain/repositories/work_schedule_repository.dart';
import '../../domain/entities/doctor_workspace.dart';
import '../../domain/repositories/doctor_workspace_repository.dart';
import '../models/doctor_report_model.dart';

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
    FirebaseFirestore? firestore,
  }) : _firestoreOverride = firestore;

  final FirebaseFirestore? _firestoreOverride;
  FirebaseFirestore get _firestore =>
      _firestoreOverride ?? FirebaseFirestore.instance;

  final DoctorRepository doctorRepository;
  final WorkScheduleRepository workScheduleRepository;
  final TimeSlotRepository timeSlotRepository;
  final AppointmentRepository appointmentRepository;

  @override
  bool get isDemo => false;

  @override
  bool get canSubmitReports => true;

  @override
  Future<DoctorDayData> loadDay({
    required String userId,
    required DateTime date,
  }) async {
    final day = DateTime(date.year, date.month, date.day);
    try {
      final resolvedDoctor = await doctorRepository.getDoctorByUserId(userId);
      if (resolvedDoctor == null ||
          !resolvedDoctor.isActive ||
          resolvedDoctor.status.toUpperCase() != 'ACTIVE') {
        throw const DoctorWorkspaceAccessException(
          'Tài khoản chưa có hồ sơ bác sĩ đang hoạt động.',
        );
      }
      // The datasource also verifies legacy accountKey ownership. Present the
      // authenticated UID to the workspace without migrating the stored profile.
      final doctor = resolvedDoctor.userId == userId
          ? resolvedDoctor
          : DoctorModel.fromJson({
              ...DoctorModel.fromEntity(resolvedDoctor).toJson(),
              'userId': userId,
            }, documentId: resolvedDoctor.id);

      final schedules = await workScheduleRepository.getWorkSchedules(
        doctorId: doctor.id,
        workDate: day,
      );
      final slotsBySchedule = await Future.wait(
        schedules.map(
          (schedule) =>
              timeSlotRepository.getTimeSlotsByWorkSchedule(schedule.id),
        ),
      );
      final slots = slotsBySchedule
          .expand((items) => items)
          .where((slot) => slot.doctorId == doctor.id)
          .toList(growable: false);
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
      if (error.code == 'permission-denied' ||
          error.code == 'unauthenticated') {
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
  Future<List<DoctorReport>> loadReports({required String userId}) async {
    final snapshot = await _firestore
        .collection(DoctorReportModel.collectionName)
        .where('senderId', isEqualTo: userId)
        .get();
    final reports = snapshot.docs.map(DoctorReportModel.fromFirestore).toList();
    reports.sort(
      (a, b) => (b.createdAt ?? b.date).compareTo(a.createdAt ?? a.date),
    );
    return List.unmodifiable(reports);
  }

  @override
  Future<DoctorReport> submitReport({
    required String userId,
    required DoctorReportDraft draft,
  }) async {
    final key = draft.requestId.trim();
    if (key.isEmpty ||
        key.contains('/') ||
        key.length > 200 ||
        !const [
          'Bận đột xuất',
          'Sự cố lịch làm',
          'Khác',
        ].contains(draft.type) ||
        draft.reason.trim().isEmpty ||
        draft.reason.length > 200 ||
        draft.description.trim().isEmpty ||
        draft.description.length > 1000) {
      throw ArgumentError('Nội dung yêu cầu không hợp lệ.');
    }
    final doctor = await doctorRepository.getDoctorByUserId(userId);
    if (doctor == null || !doctor.isActive) {
      throw const DoctorWorkspaceAccessException(
        'Không có hồ sơ bác sĩ đang hoạt động.',
      );
    }
    final reference = _firestore
        .collection(DoctorReportModel.collectionName)
        .doc(key);
    final fields = <String, dynamic>{
      'senderId': userId,
      'doctorId': doctor.id,
      'scheduleId': draft.scheduleId,
      'type': draft.type,
      'date': Timestamp.fromDate(
        DateTime(draft.date.year, draft.date.month, draft.date.day),
      ),
      'reason': draft.reason.trim(),
      'description': draft.description.trim(),
    };
    await _firestore.runTransaction((tx) async {
      final existing = await tx.get(reference);
      if (existing.exists) {
        if (!fields.entries
                .where((field) => field.key != 'date')
                .every((field) => existing.data()?[field.key] == field.value) ||
            !_sameDay(
              (existing.data()?['date'] as Timestamp?)?.toDate(),
              draft.date,
            )) {
          throw StateError('Mã yêu cầu đã được dùng cho nội dung khác.');
        }
        return;
      }
      final schedule = await tx.get(
        _firestore.collection('LICH_LAM_VIEC').doc(draft.scheduleId),
      );
      final data = schedule.data();
      final scheduleDate = (data?['workDate'] as Timestamp?)?.toDate();
      if (data?['doctorId'] != doctor.id ||
          data?['status'] != 'ACTIVE' ||
          !_sameDay(scheduleDate, draft.date)) {
        throw StateError('Ca làm không thuộc bác sĩ hoặc ngày đã chọn.');
      }
      tx.set(reference, {
        ...fields,
        'date': data!['workDate'],
        'status': 'PENDING',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
    return DoctorReportModel.fromFirestore(await reference.get());
  }
}
