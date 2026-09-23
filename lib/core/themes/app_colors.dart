import 'package:flutter/material.dart';

abstract final class AppColors {
  // BRAND
  static const Color primary = Color.fromARGB(255, 161, 223, 252);
  static const Color primaryDark = Color(0xFF2563EB);
  static const Color primaryLight = Color(0xFFDBEAFE);
  static const Color primarySoft = Color(0xFFEFF6FF);

  // BACKGROUND
  static const Color background = Color(0xFFF8FBFF);
  static const Color surface = Color(0xFFFFFFFF);

  // TEXT
  static const Color textPrimary = Color.fromARGB(255, 0, 0, 0);
  static const Color textSecondary = Color.fromARGB(255, 100, 116, 139);
  static const Color textOnPrimary = Color.fromARGB(255, 17, 81, 154);

  // BORDER
  static const Color border = Color.fromARGB(255, 152, 189, 238);
  static const Color divider = Color(0xFFF1F5F9);

  // STATUS
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF0EA5E9);

  // DISABLED
  static const Color disabled = Color(0xFFCBD5E1);
}
