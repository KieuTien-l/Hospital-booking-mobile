import '../../domain/entities/patient.dart';

/// Presentation-only fixtures. Replace at the navigation entry when integrating data.
abstract final class PatientProfileDemoData {
  static const profiles = [
    Patient(
      id: 'DEMO-001',
      authUserId: 'demo-account',
      fullName: 'Nguyễn Minh An',
      phone: '0900000123',
      email: '',
      isActive: true,
      relationshipToAccountHolder: 'Tôi',
    ),
  ];

  static const ethnicities = ['Kinh', 'Tày', 'Thái', 'Hoa', 'Khác'];
  static const occupations = [
    'Nhân viên văn phòng',
    'Học sinh / Sinh viên',
    'Lao động tự do',
    'Hưu trí',
    'Khác',
  ];
  static const relationships = [
    'Tôi',
    'Cha / Mẹ',
    'Vợ / Chồng',
    'Con',
    'Anh / Chị / Em',
    'Khác',
  ];
}
