import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/auth/domain/entities/user_entity.dart';
import '../../features/auth/presentation/controllers/auth_controller.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/home/presentation/pages/patient_home_page.dart';
import '../../features/home/presentation/pages/doctor_home_page.dart';
import '../../features/home/presentation/pages/admin_home_page.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    if (auth.status == AuthStatus.authenticated && auth.currentUser != null) {
      switch (auth.currentUser!.role) {
        case UserRole.patient:
          return const PatientHomePage();
        case UserRole.doctor:
          return const DoctorHomePage();
        case UserRole.admin:
          return const AdminHomePage();
      }
    }

    return const LoginPage();
  }
}
