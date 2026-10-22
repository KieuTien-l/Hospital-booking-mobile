import '../../../doctors/domain/entities/doctor.dart';
import '../../../doctors/domain/entities/time_slot.dart';
import '../../../doctors/domain/entities/work_schedule.dart';
import '../../../specialties/domain/entities/specialty.dart';

/// Write boundary for administrator-only master data operations.
///
/// Implementations must validate referenced documents in one transaction before
/// persisting a change. Firestore rules remain the final authorization check.
abstract class AdminManagementRepository {
  Future<Specialty> saveSpecialty(Specialty specialty);

  Future<Doctor> saveDoctor(Doctor doctor);

  /// Moves a doctor to an active specialty.
  ///
  /// Existing appointments retain their specialty as the historical booking
  /// snapshot; schedules stay attached to the same doctor.
  Future<Doctor> transferDoctorToSpecialty({
    required String doctorId,
    required String targetSpecialtyId,
  });

  Future<WorkSchedule> saveWorkSchedule(WorkSchedule schedule);

  Future<TimeSlot> saveTimeSlot(TimeSlot timeSlot);
}
