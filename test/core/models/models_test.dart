import 'package:flutter_application_4/core/entities/user_entity.dart';
import 'package:flutter_application_4/core/models/doctor_model.dart';
import 'package:flutter_application_4/core/models/specialty_model.dart';
import 'package:flutter_application_4/core/models/user_model.dart';
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

    test('serializes the canonical user schema', () {
      const user = UserModel(
        id: 'user-1',
        email: 'doctor@example.com',
        fullName: 'Doctor One',
        phone: '0900000000',
        role: UserRole.doctor,
        isActive: true,
      );

      expect(user.toJson(), {
        'id': 'user-1',
        'email': 'doctor@example.com',
        'fullName': 'Doctor One',
        'phone': '0900000000',
        'role': 'doctor',
        'isActive': true,
      });
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
  });
}
