import 'package:flutter/material.dart';

class AdminHomePage extends StatelessWidget {
  const AdminHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Đây là trang chủ dành cho quản trị viên.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
