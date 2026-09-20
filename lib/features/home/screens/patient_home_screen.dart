import 'package:flutter/material.dart';
import '../../auth/data/datasources/auth_firebase_datasource.dart';
import '../../auth/data/repositories/auth_repository_impl.dart';
import '../../auth/domain/repositories/auth_repository.dart';
import '../../auth/screens/login_screen.dart';

class PatientHomeScreen extends StatelessWidget {
  const PatientHomeScreen({super.key});

  void _logout(BuildContext context) async {
    final AuthRepository authRepo = AuthRepositoryImpl(AuthFirebaseDatasource());
    await authRepo.logout();
    if (context.mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trang Bệnh Nhân'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
          )
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Chào mừng bạn đến với ứng dụng đặt lịch khám!',
              style: TextStyle(fontSize: 20),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {},
              child: const Text('Đặt lịch khám ngay'),
            ),
          ],
        ),
      ),
    );
  }
}
