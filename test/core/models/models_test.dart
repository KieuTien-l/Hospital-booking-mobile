import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application_4/core/entities/user_entity.dart';
import 'package:flutter_application_4/core/models/appointment_model.dart';
import 'package:flutter_application_4/core/models/doctor_model.dart';
import 'package:flutter_application_4/core/models/patient_model.dart';
import 'package:flutter_application_4/core/models/specialty_model.dart';
import 'package:flutter_application_4/core/models/time_slot_model.dart';
import 'package:flutter_application_4/core/models/user_model.dart';
import 'package:flutter_application_4/core/models/work_schedule_model.dart';
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

    test('maps legacy TAI_KHOAN data and writes the canonical fields', () {
      final user = UserModel.fromJson(const {
        'Khoa': 'Noi Tim mach',
        'MaTK': 161,
        'Quyen': 'DOCTOR',
        'TrangThai': 'ACTIVE',
        'Email': 'doctor@example.com',
        'HoTen': 'Doctor One',
        'SoDienThoai': '0900000000',
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
    });
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

    test('maps the CHUYEN_KHOA Firestore fields and document id', () {
      final specialty = Specialty.fromMap(const {
        'TenChuyenKhoa': 'Tim mach',
        'MoTa': 'Kham va dieu tri tim mach',
        'HinhAnh': 'https://example.com/tim-mach.png',
        'TrangThai': 'ACTIVE',
      }, documentId: 'ck-1');

      expect(specialty.id, 'ck-1');
      expect(specialty.tenChuyenKhoa, 'Tim mach');
      expect(specialty.moTa, 'Kham va dieu tri tim mach');
      expect(specialty.hinhAnh, contains('tim-mach'));
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

    test('maps a doctor to its specialty', () {
      final doctor = Doctor.fromMap(const {
        'HoTen': 'Nguyen Van An',
        'MaCK': 'ck-1',
        'MaTK': 'user-1',
        'KinhNghiem': 12,
        'GiaKham': 200000,
        'HocHamHocVi': 'Bac si chuyen khoa I',
        'AnhDaiDien': 'doctor.png',
        'MoTaChiTiet': 'Kham noi tong quat',
        'TrangThai': 'ACTIVE',
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

    test('maps LICH_LAM_VIEC date and time fields', () {
      final schedule = WorkSchedule.fromMap({
        'MaBS': 'bs-1',
        'NgayLamViec': Timestamp.fromDate(start),
        'GioBatDau': '08:00',
        'GioKetThuc': '08:30',
      }, documentId: 'llv-1');

      expect(schedule.id, 'llv-1');
      expect(schedule.doctorId, 'bs-1');
      expect(schedule.workDate!.isAtSameMomentAs(start), isTrue);
      expect(schedule.startTime, '08:00');
      expect(schedule.endTime, '08:30');
    });

    test('maps CA_KHAM status and schedule relationship', () {
      final slot = TimeSlot.fromMap({
        'MaLLV': 'llv-1',
        'MaBS': 'bs-1',
        'GioBatDau': '08:00',
        'GioKetThuc': '08:30',
        'SoLuongDaDat': 0,
        'SoLuongToiDa': 5,
        'TrangThai': 'AVAILABLE',
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
      final slot = TimeSlot.fromMap(const {
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

    test('maps LICH_HEN to patient, doctor, schedule and slot', () {
      final appointment = Appointment.fromMap({
        'MyBN': 'bn-1',
        'MaBS': 'bs-1',
        'MaCK': 'ck-1',
        'MaLLV': 'llv-1',
        'Maca': 'ca-1',
        'NgayDat': Timestamp.fromDate(start),
        'SoNguoiKham': 1,
        'SoThuTuKham': 2,
        'TrangThai': 'CONFIRMED',
        'TrieuChung': 'Dau dau',
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

      final fields = appointment.toFirestore();
      expect(fields['appointmentDate'], start);
      expect(fields['startTime'], '08:00');
      expect(fields['endTime'], '08:30');
      expect(fields['peopleCount'], 2);
    });
  });

  group('Patient', () {
    test('maps BENH_NHAN and tolerates optional missing fields', () {
      final patient = Patient.fromMap(const {
        'MaTK': 'firebase-uid-1',
        'HoTen': 'Tran Thi Binh',
        'SoDienThoai': '0900000000',
        'Email': 'binh@example.com',
        'MaBHYT': 'BHYT-01',
        'DanToc': 'Kinh',
        'NgheNghiep': 'Sinh vien',
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
      () => Specialty.fromMap(const {}, documentId: 'ck-1'),
      returnsNormally,
    );
    expect(() => Doctor.fromMap(const {}, documentId: 'bs-1'), returnsNormally);
    expect(
      () => WorkSchedule.fromMap(const {}, documentId: 'llv-1'),
      returnsNormally,
    );
    expect(
      () => TimeSlot.fromMap(const {}, documentId: 'slot-1'),
      returnsNormally,
    );
    expect(
      () => Appointment.fromMap(const {}, documentId: 'appointment-1'),
      returnsNormally,
    );
    expect(
      () => Patient.fromMap(const {}, documentId: 'bn-1'),
      returnsNormally,
    );
  });
}
