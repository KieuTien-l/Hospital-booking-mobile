import '../../domain/entities/patient.dart';

/// Presentation-only fixtures for the health profiles page.
abstract final class PatientProfilesDemoData {
  static const profiles = [
    Patient(
      id: 'DEMO-BN001',
      authUserId: 'demo-account',
      fullName: 'Nguyễn Văn An',
      phone: '0910000678',
      email: '',
      isActive: true,
      relationshipToAccountHolder: 'Tôi',
    ),
    Patient(
      id: 'DEMO-BN002',
      authUserId: 'demo-account',
      fullName: 'Nguyễn Minh Anh',
      phone: '0910000678',
      email: '',
      isActive: true,
      relationshipToAccountHolder: 'Con',
    ),
    Patient(
      id: 'DEMO-BN003',
      authUserId: 'demo-account',
      fullName: 'Trần Thị Mai',
      phone: '0980000432',
      email: '',
      isActive: true,
      relationshipToAccountHolder: 'Mẹ',
    ),
  ];
}
