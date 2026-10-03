import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../auth/presentation/controllers/auth_controller.dart';
import '../widgets/patient_home_view.dart';

class PatientHomePage extends StatelessWidget {
  const PatientHomePage({super.key});
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    return PatientHomeView(
      fullName: auth.currentUser?.fullName ?? '',
      email: auth.currentUser?.email ?? '',
      onLogout: () => auth.logout(),
    );
  }
}
