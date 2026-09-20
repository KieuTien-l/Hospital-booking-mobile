enum UserRole {
  patient,
  doctor,
  admin,
}

class UserEntity {
  final String id;
  final String email;
  final String fullName;
  final String phone;
  final UserRole role;
  final bool isActive;

  const UserEntity({
    required this.id,
    required this.email,
    required this.fullName,
    required this.phone,
    required this.role,
    required this.isActive,
  });
}
