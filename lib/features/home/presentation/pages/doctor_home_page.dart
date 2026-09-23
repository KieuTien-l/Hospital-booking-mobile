import 'package:flutter/material.dart';

class DoctorHomePage extends StatelessWidget {
  const DoctorHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Đây là trang chủ dành cho bác sĩ.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
