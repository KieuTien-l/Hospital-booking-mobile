import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application_4/features/auth/domain/entities/user_entity.dart';
import 'package:flutter_application_4/features/appointments/data/models/appointment_model.dart';
import 'package:flutter_application_4/features/doctors/data/models/doctor_model.dart';
import 'package:flutter_application_4/features/profile/data/models/patient_model.dart';
import 'package:flutter_application_4/features/specialties/data/models/specialty_model.dart';
import 'package:flutter_application_4/features/doctors/data/models/time_slot_model.dart';
import 'package:flutter_application_4/features/auth/data/models/user_model.dart';
import 'package:flutter_application_4/features/doctors/data/models/work_schedule_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UserModel', () {
    test('parses missing optional values safely', () {
      final user = UserModel.fromJson(const {
        'id': 'user-1',
        'email': 'patient@example.com',
      });

      expect(user.id, 'user-1');
      expect(user.fullName, isEmpty);
      expect(user.phone, isEmpty);
      expect(user.role, UserRole.patient);
      expect(user.isActive, isTrue);
    });

    test(
      'reads canonical TAI_KHOAN fields and writes the canonical fields',
      () {
        final user = UserModel.fromJson(const {
          'department': 'Noi Tim mach',
          'accountKey': '161',
          'permission': 'DOCTOR',
          'status': 'ACTIVE',
          'role': 'doctor',
          'email': 'doctor@example.com',
          'fullName': 'Doctor One',
          'phone': '0900000000',
        }, documentId: 'user-1');

        expect(user.department, 'Noi Tim mach');
        expect(user.accountKey, '161');
        expect(user.permission, 'DOCTOR');
        expect(user.status, 'ACTIVE');
        expect(user.role, UserRole.doctor);
        expect(
          user.toFirestoreCreate().keys,
          unorderedEquals(const [
            'createdAt',
            'email',
            'fullName',
            'isActive',
            'phone',
            'role',
            'updatedAt',
          ]),
        );
        expect(user.toFirestoreCreate()['role'], 'doctor');
      },
    );
  });

  group('SpecialtyModel', () {
    test('round trips JSON values', () {
      final specialty = SpecialtyModel.fromJson(const {
        'id': 'cardiology',
        'name': 'Cardiology',
        'description': 'Heart care',
        'isActive': true,
        'imageUrl': 'https://example.com/cardiology.png',
      });

      expect(specialty.toJson()['name'], 'Cardiology');
      expect(specialty.toJson()['imageUrl'], contains('cardiology'));
    });

    test('maps canonical CHUYEN_KHOA fields and document id', () {
      final specialty = SpecialtyModel.fromMap(const {
        'name': 'Tim mach',
        'description': 'Kham va dieu tri tim mach',
        'imageUrl': 'https://example.com/tim-mach.png',
        'status': 'ACTIVE',
      }, documentId: 'ck-1');

      expect(specialty.id, 'ck-1');
      expect(specialty.tenChuyenKhoa, 'Tim mach');
      expect(specialty.moTa, 'Kham va dieu tri tim mach');
      expect(specialty.hinhAnh, contains('tim-mach'));
      expect(specialty.isActive, isTrue);
    });

    test('reads legacy Vietnamese Firestore fields', () {
      final specialty = SpecialtyModel.fromMap(const {
        'TenChuyenKhoa': 'Khoa Nội Tim mạch',
        'MoTa': 'Khám và điều trị bệnh lý tim mạch',
        'HinhAnh': 'Noi_Tim_Mach.png',
        'TrangThai': 'ACTIVE',
      }, documentId: 'cardiology');

      expect(specialty.name, 'Khoa Nội Tim mạch');
      expect(specialty.description, 'Khám và điều trị bệnh lý tim mạch');
      expect(specialty.imageUrl, 'Noi_Tim_Mach.png');
      expect(specialty.isActive, isTrue);
    });
  });

  group('DoctorModel', () {
    test('normalizes numeric values received from JSON', () {
      final doctor = DoctorModel.fromJson(const {
        'id': 'doctor-1',
        'userId': 'user-1',
        'fullName': 'Doctor One',
        'email': 'doctor@example.com',
        'phone': '0900000000',
        'specialtyId': 'cardiology',
        'yearsOfExperience': '10',
        'consultationFee': 150000,
        'isActive': 'true',
      });

      expect(doctor.yearsOfExperience, 10);
      expect(doctor.consultationFee, 150000);
      expect(doctor.isActive, isTrue);
      expect(doctor.toJson()['specialtyId'], 'cardiology');
    });

    test('maps a canonical doctor to its specialty', () {
      final doctor = DoctorModel.fromMap(const {
        'fullName': 'Nguyen Van An',
        'specialtyId': 'ck-1',
        'userId': 'user-1',
        'yearsOfExperience': 12,
        'consultationFee': 200000,
        'qualification': 'Bac si chuyen khoa I',
        'avatarUrl': 'doctor.png',
        'biography': 'Kham noi tong quat',
        'status': 'ACTIVE',
      }, documentId: 'bs-1');

      expect(doctor.id, 'bs-1');
      expect(doctor.tenBacSi, 'Nguyen Van An');
      expect(doctor.maChuyenKhoa, 'ck-1');
      expect(doctor.userId, 'user-1');
      expect(doctor.yearsOfExperience, 12);
      expect(doctor.consultationFee, 200000);
      expect(doctor.qualification, 'Bac si chuyen khoa I');
    });
  });

  group('Scheduling models', () {
    final start = DateTime.utc(2026, 10, 1, 8);

    test('maps canonical LICH_LAM_VIEC date and time fields', () {
      final schedule = WorkScheduleModel.fromMap({
        'doctorId': 'bs-1',
        'workDate': Timestamp.fromDate(start),
        'startTime': '08:00',
        'endTime': '08:30',
      }, documentId: 'llv-1');

      expect(schedule.id, 'llv-1');
      expect(schedule.doctorId, 'bs-1');
      expect(schedule.workDate!.isAtSameMomentAs(start), isTrue);
      expect(schedule.startTime, '08:00');
      expect(schedule.endTime, '08:30');
    });

    test('maps canonical CA_KHAM status and schedule relationship', () {
      final slot = TimeSlotModel.fromMap({
        'workScheduleId': 'llv-1',
        'doctorId': 'bs-1',
        'startTime': '08:00',
        'endTime': '08:30',
        'bookedCount': 0,
        'capacity': 5,
        'status': 'AVAILABLE',
      }, documentId: 'ck-1');

      expect(slot.id, 'ck-1');
      expect(slot.workScheduleId, 'llv-1');
      expect(slot.doctorId, 'bs-1');
      expect(slot.startTime, '08:00');
      expect(slot.endTime, '08:30');
      expect(slot.bookedCount, 0);
      expect(slot.capacity, 5);
      expect(slot.status, TimeSlotStatus.available);
      expect(slot.isAvailable, isTrue);
    });

    test('reads canonical CA_KHAM counters', () {
      final slot = TimeSlotModel.fromMap(const {
        'workScheduleId': 'llv-1',
        'doctorId': 'bs-1',
        'bookedCount': 2,
        'capacity': 5,
        'status': 'AVAILABLE',
      }, documentId: 'ca-1');

      expect(slot.bookedCount, 2);
      expect(slot.capacity, 5);
      expect(slot.isAvailable, isTrue);
    });

    test('maps canonical LICH_HEN to patient, doctor, schedule and slot', () {
      final appointment = AppointmentModel.fromMap({
        'patientId': 'bn-1',
        'doctorId': 'bs-1',
        'specialtyId': 'ck-1',
        'workScheduleId': 'llv-1',
        'timeSlotId': 'ca-1',
        'bookedAt': Timestamp.fromDate(start),
        'peopleCount': 1,
        'queueNumber': 2,
        'status': 'CONFIRMED',
        'symptoms': 'Dau dau',
      }, documentId: 'lh-1');

      expect(appointment.id, 'lh-1');
      expect(appointment.patientId, 'bn-1');
      expect(appointment.doctorId, 'bs-1');
      expect(appointment.specialtyId, 'ck-1');
      expect(appointment.workScheduleId, 'llv-1');
      expect(appointment.timeSlotId, 'ca-1');
      expect(appointment.bookedAt!.isAtSameMomentAs(start), isTrue);
      expect(appointment.peopleCount, 1);
      expect(appointment.queueNumber, 2);
      expect(appointment.symptoms, 'Dau dau');
      expect(appointment.status, AppointmentStatus.confirmed);
    });

    test('writes appointment date, time and people count to Firestore', () {
      final appointment = Appointment(
        id: 'lh-1',
        patientId: 'bn-1',
        doctorId: 'bs-1',
        workScheduleId: 'llv-1',
        timeSlotId: 'ca-1',
        specialtyId: 'ck-1',
        appointmentDate: start,
        startTime: '08:00',
        endTime: '08:30',
        bookedAt: start,
        status: AppointmentStatus.pending,
        peopleCount: 2,
      );

      final fields = AppointmentModel.fromEntity(appointment).toFirestore();
      expect(fields['appointmentDate'], start);
      expect(fields['startTime'], '08:00');
      expect(fields['endTime'], '08:30');
      expect(fields['peopleCount'], 2);
    });
  });

  group('Patient', () {
    test('maps canonical BENH_NHAN and tolerates optional missing fields', () {
      final patient = PatientModel.fromMap(const {
        'authUserId': 'firebase-uid-1',
        'fullName': 'Tran Thi Binh',
        'phone': '0900000000',
        'email': 'binh@example.com',
        'insuranceNumber': 'BHYT-01',
        'ethnicity': 'Kinh',
        'occupation': 'Sinh vien',
      }, documentId: 'bn-1');

      expect(patient.id, 'bn-1');
      expect(patient.uid, 'firebase-uid-1');
      expect(patient.tenBenhNhan, 'Tran Thi Binh');
      expect(patient.insuranceNumber, 'BHYT-01');
      expect(patient.ethnicity, 'Kinh');
      expect(patient.occupation, 'Sinh vien');
      expect(patient.dateOfBirth, isNull);
      expect(patient.isActive, isTrue);
    });
  });

  test('all patient-module models tolerate a missing Firestore payload', () {
    expect(
      () => SpecialtyModel.fromMap(const {}, documentId: 'ck-1'),
      returnsNormally,
    );
    expect(
      () => DoctorModel.fromMap(const {}, documentId: 'bs-1'),
      returnsNormally,
    );
    expect(
      () => WorkScheduleModel.fromMap(const {}, documentId: 'llv-1'),
      returnsNormally,
    );
    expect(
      () => TimeSlotModel.fromMap(const {}, documentId: 'slot-1'),
      returnsNormally,
    );
    expect(
      () => AppointmentModel.fromMap(const {}, documentId: 'appointment-1'),
      returnsNormally,
    );
    expect(
      () => PatientModel.fromMap(const {}, documentId: 'bn-1'),
      returnsNormally,
    );
  });
}
