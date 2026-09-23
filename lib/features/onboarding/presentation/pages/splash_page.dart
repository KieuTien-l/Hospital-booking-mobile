import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hospital_booking_app/features/auth/presentation/pages/login_page.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 10), () {
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        body: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final height = constraints.maxHeight;
            final brandScale = math.min(width / 390, height / 800);

            return DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [Color(0xFFF0F9FF), Color(0xFFC8E3FF)],
                ),
              ),
              child: Stack(
                fit: StackFit.expand,
                clipBehavior: Clip.hardEdge,
                children: [
                  Positioned(
                    top: height * 0.055 - width * 0.60,
                    right: -width * 0.61,
                    child: Container(
                      width: width * 1.20,
                      height: width * 1.20,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFFD5EAFF), Color(0xFF88BEFA)],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: height * 0.71,
                    left: -width * 0.85,
                    child: Container(
                      width: width * 1.62,
                      height: width * 1.62,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topRight,
                          end: Alignment.bottomLeft,
                          colors: [Color(0xFFD4EAFF), Color(0xFF8CC2FB)],
                        ),
                      ),
                    ),
                  ),
                  Align(
                    alignment: const Alignment(0, -0.035),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ClipRect(
                          child: Align(
                            widthFactor: 0.54,
                            heightFactor: 0.54,
                            child: Image.asset(
                              'assets/images/logo.png',
                              width: 285 * brandScale,
                              fit: BoxFit.contain,
                              excludeFromSemantics: true,
                            ),
                          ),
                        ),
                        SizedBox(height: 16 * brandScale),
                        ClipRect(
                          child: Align(
                            widthFactor: 0.84,
                            heightFactor: 0.56,
                            child: Image.asset(
                              'assets/images/name_logo.png',
                              width: 267 * brandScale,
                              fit: BoxFit.contain,
                              semanticLabel: 'HealWay',
                            ),
                          ),
                        ),
                        SizedBox(height: 12 * brandScale),
                        const Text(
                          'GẦN HƠN VỚI SỨC KHỎE',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Montserrat',
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 3.0,
                            height: 1.8,
                            color: Color(0xFF164B91),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
