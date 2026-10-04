import 'package:flutter/material.dart';

class PatientHomeHeader extends StatelessWidget {
  const PatientHomeHeader({super.key});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      // Match the reference proportions while keeping the title on one line.
      final scale = constraints.maxWidth / 700;
      return Padding(
        padding: EdgeInsets.fromLTRB(
          24 * scale,
          80 * scale,
          24 * scale,
          45 * scale,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Chào mừng đến với',
              style: TextStyle(
                fontSize: 34 * scale,
                height: 1.35,
                color: const Color(0xFF2267B2),
                fontWeight: FontWeight.w400,
              ),
            ),
            SizedBox(height: 5 * scale),
            const FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'Bệnh viện Quốc tế ',
                      style: TextStyle(color: Color(0xFF0864CA)),
                    ),
                    TextSpan(
                      text: 'Meridian',
                      style: TextStyle(color: Color(0xFF20B0EE)),
                    ),
                  ],
                ),
                maxLines: 1,
                style: TextStyle(
                  fontSize: 48,
                  height: 1.3,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1.5,
                ),
              ),
            ),
            SizedBox(height: 7 * scale),
            ClipRect(
              child: Align(
                alignment: Alignment.center,
                widthFactor: .84,
                heightFactor: .56,
                child: Image.asset(
                  'assets/images/name_logo.png',
                  width: 380 * scale,
                  fit: BoxFit.contain,
                  semanticLabel: 'HealWay',
                ),
              ),
            ),
            SizedBox(height: 4 * scale),
            Text(
              'Ứng dụng dành cho bệnh nhân',
              style: TextStyle(
                fontSize: 25 * scale,
                height: 1.4,
                color: const Color(0xFF5685B9),
              ),
            ),
          ],
        ),
      );
    },
  );
}
