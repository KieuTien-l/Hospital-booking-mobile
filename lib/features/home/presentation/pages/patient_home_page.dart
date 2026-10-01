import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../widgets/patient_home_view.dart';

class PatientHomePage extends StatelessWidget {
  const PatientHomePage({super.key});
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return PatientHomeView(
      fullName: auth.currentUser?.fullName ?? '',
      email: auth.currentUser?.email ?? '',
      onLogout: () => auth.logout(),
    );
  }
}
