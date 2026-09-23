import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class AdminHomePage extends StatelessWidget {
  const AdminHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
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
                const Icon(Icons.admin_panel_settings_rounded, size: 64, color: Color(0xFF0060EF)),
                const SizedBox(height: 16),
                Text(
                  user != null && user.fullName.isNotEmpty
                      ? 'Xin chào Quản trị viên, ${user.fullName}!'
                      : 'Chào mừng Quản trị viên!',
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
                  'Đây là trang chủ dành cho quản trị viên.',
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
