import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/auth/domain/entities/user_entity.dart';
import '../../features/auth/presentation/controllers/auth_controller.dart';
import '../../features/auth/presentation/pages/account_locked_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/home/presentation/pages/patient_home_page.dart';
import '../../features/home/presentation/widgets/doctor_workspace_shell.dart';
import '../../features/home/presentation/pages/admin_home_page.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key, this.useLiveCommunications = false});
  final bool useLiveCommunications;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    if (auth.isLocked) return const AccountLockedPage();

    if (auth.status == AuthStatus.authenticated && auth.currentUser != null) {
      switch (auth.currentUser!.role) {
        case UserRole.patient:
          return PatientHomePage(useLiveCommunications: useLiveCommunications);
        case UserRole.doctor:
          if (!auth.currentUser!.isActive) return const LoginPage();
          return DoctorWorkspaceShell(key: ValueKey(auth.currentUser!.id));
        case UserRole.admin:
          return const AdminHomePage();
      }
    }

    return const LoginPage();
  }
}
