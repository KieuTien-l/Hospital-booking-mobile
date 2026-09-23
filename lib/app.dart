import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/entities/user_entity.dart';
import 'core/themes/app_theme.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/home/presentation/pages/admin_home_page.dart';
import 'features/home/presentation/pages/doctor_home_page.dart';
import 'features/home/presentation/pages/patient_home_page.dart';
import 'features/onboarding/presentation/pages/splash_page.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthProvider(),
      child: MaterialApp(
        title: 'HealWay',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const SplashPage(),
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

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
