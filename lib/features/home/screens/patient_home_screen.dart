import 'package:flutter/material.dart';

import '../../auth/data/datasources/auth_firebase_datasource.dart';
import '../../auth/data/repositories/auth_repository_impl.dart';
import '../../auth/screens/login_screen.dart';
import '../presentation/widgets/patient_home_view.dart';

class PatientHomeScreen extends StatelessWidget {
  const PatientHomeScreen({super.key});
  Future<void> _logout(BuildContext context) async {
    await AuthRepositoryImpl(AuthFirebaseDatasource()).logout();
    if (context.mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) =>
      PatientHomeView(onLogout: () => _logout(context));
}
