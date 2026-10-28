import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/auth_controller.dart';

/// Shown instead of the application when an administrator has locked the
/// signed-in account. It deliberately exposes no patient or staff data.
class AccountLockedPage extends StatelessWidget {
  const AccountLockedPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FBFF),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: const BorderSide(color: Color(0xFFF2C5C9)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 76,
                        height: 76,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFFECEE),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.lock_outline_rounded,
                          color: Color(0xFFC33E4C),
                          size: 38,
                        ),
                      ),
                      const SizedBox(height: 22),
                      const Text(
                        'Tài khoản của bạn đã bị khóa',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'BeVietnamPro',
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF143D70),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Bạn hiện không thể sử dụng các chức năng của hệ thống. Vui lòng liên hệ quản trị viên để được hỗ trợ.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'BeVietnamPro',
                          fontSize: 14,
                          height: 1.55,
                          color: Color(0xFF647990),
                        ),
                      ),
                      const SizedBox(height: 26),
                      FilledButton.icon(
                        onPressed: () =>
                            context.read<AuthController>().logout(),
                        icon: const Icon(Icons.logout_rounded),
                        label: const Text('Đăng xuất'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                          backgroundColor: const Color(0xFF0060EF),
                          foregroundColor: Colors.white,
                          textStyle: const TextStyle(
                            fontFamily: 'BeVietnamPro',
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
