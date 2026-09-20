import 'package:flutter/material.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/home/screens/patient_home_screen.dart';
import 'features/home/screens/doctor_home_screen.dart';
import 'features/home/screens/admin_home_screen.dart';
import 'core/entities/user_entity.dart';
import 'features/auth/domain/repositories/auth_repository.dart';
import 'features/auth/data/datasources/auth_firebase_datasource.dart';
import 'features/auth/data/repositories/auth_repository_impl.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ứng Dụng Đặt Lịch Khám',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final AuthRepository _authRepo = AuthRepositoryImpl(AuthFirebaseDatasource());

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<String?>(
      stream: _authRepo.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Đã đăng nhập
        if (snapshot.hasData && snapshot.data != null) {
          final uid = snapshot.data!;
          
          return FutureBuilder<UserEntity?>(
            // Gọi qua datasource cho nhanh vì interface cũ chưa có get currentUser
            // Thực tế nên sửa lại interface
            future: AuthFirebaseDatasource().getUser(uid),
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              
              if (userSnapshot.hasData) {
                final user = userSnapshot.data!;
                
                if (!user.isActive) {
                  // Đã bị khóa, trả về login kèm thông báo
                  _authRepo.logout();
                  return const LoginScreen();
                }

                if (user.role == UserRole.patient) {
                  return const PatientHomeScreen();
                } else if (user.role == UserRole.doctor) {
                  return const DoctorHomeScreen();
                } else if (user.role == UserRole.admin) {
                  return const AdminDashboard();
                }
              }
              
              return const LoginScreen();
            },
          );
        }

        // Chưa đăng nhập
        return const LoginScreen();
      },
    );
  }
}
