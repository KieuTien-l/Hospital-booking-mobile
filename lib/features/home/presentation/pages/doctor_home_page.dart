import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class DoctorHomePage extends StatelessWidget {
  const DoctorHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bác Sĩ Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Đăng xuất',
            onPressed: () => context.read<AuthProvider>().logout(),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.medical_services_rounded, size: 64, color: Color(0xFF0060EF)),
                const SizedBox(height: 16),
                Text(
                  user != null && user.fullName.isNotEmpty
                      ? 'Xin chào, Bác sĩ ${user.fullName}!'
                      : 'Chào mừng Bác sĩ!',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                if (user != null && user.email.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    user.email,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
                const SizedBox(height: 16),
                const Text(
                  'Đây là trang chủ dành cho bác sĩ.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
