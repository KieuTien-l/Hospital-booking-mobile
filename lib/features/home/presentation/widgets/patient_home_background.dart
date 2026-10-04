import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Soft medical motifs scaled to the available screen size.
class PatientHomeBackground extends StatelessWidget {
  const PatientHomeBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: const _MedicalBackgroundPainter(), child: child);
}

class _MedicalBackgroundPainter extends CustomPainter {
  const _MedicalBackgroundPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas.save();
    canvas.clipRect(bounds);
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFBCE2FC),
            Color(0xFFEAF6FF),
            Color(0xFFF8FCFF),
            Color(0xFFF5FAFF),
            Color(0xFFCEEAFE),
          ],
          stops: [0, .30, .55, .78, 1],
        ).createShader(bounds),
    );
    // Use the reference's portrait proportions for the decorative paths.
    canvas.scale(size.width / 853, size.height / 1844);

    final ribbon = Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: .25);
    canvas.drawPath(
      Path()
        ..moveTo(-80, -100)
        ..cubicTo(170, 230, 390, 385, 930, 505)
        ..lineTo(930, 665)
        ..cubicTo(620, 400, 305, 420, -80, 230)
        ..close(),
      ribbon,
    );
    canvas.drawPath(
      Path()
        ..moveTo(110, -30)
        ..cubicTo(300, 270, 600, 325, 880, 40)
        ..lineTo(880, -30)
        ..close(),
      ribbon,
    );
    canvas.drawPath(
      Path()
        ..moveTo(-50, 655)
        ..cubicTo(220, 850, 590, 690, 900, 1160)
        ..lineTo(900, 940)
        ..cubicTo(610, 570, 245, 650, -50, 420)
        ..close(),
      Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: .18),
    );
    canvas.drawPath(
      Path()
        ..moveTo(-50, 1330)
        ..cubicTo(280, 1480, 400, 1850, 900, 1560)
        ..lineTo(900, 1640)
        ..cubicTo(510, 1640, 420, 1890, 190, 1860)
        ..cubicTo(280, 1650, 120, 1550, -50, 1500)
        ..close(),
      ribbon,
    );

    final line = Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: .55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    for (final path in [
      Path()
        ..moveTo(105, -20)
        ..cubicTo(250, 220, 715, 210, 870, 380),
      Path()
        ..moveTo(-20, 455)
        ..cubicTo(245, 685, 490, 550, 700, 635),
      Path()
        ..moveTo(-20, 765)
        ..quadraticBezierTo(95, 740, 160, 700),
      Path()
        ..moveTo(-20, 1435)
        ..cubicTo(350, 1500, 285, 1740, 640, 1685)
        ..quadraticBezierTo(770, 1665, 875, 1685),
      Path()
        ..moveTo(-20, 1605)
        ..cubicTo(310, 1800, 580, 1690, 875, 1680),
      Path()
        ..moveTo(-20, 1730)
        ..quadraticBezierTo(120, 1770, 155, 1855),
    ]) {
      canvas.drawPath(path, line);
    }

    void cross(double x, double y, double diameter) {
      final paint = Paint()
        ..color = const Color(0xFF8BCDF8).withValues(alpha: .25);
      final thickness = diameter * .35;
      for (final rect in [
        Rect.fromCenter(
          center: Offset(x, y),
          width: thickness,
          height: diameter,
        ),
        Rect.fromCenter(
          center: Offset(x, y),
          width: diameter,
          height: thickness,
        ),
      ]) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(diameter * .07)),
          paint,
        );
      }
    }

    void hexagon(double x, double y, double radius, {bool outline = false}) {
      final path = Path();
      for (var i = 0; i < 6; i++) {
        final angle = math.pi / 3 * i - math.pi / 2;
        final point = Offset(
          x + radius * math.cos(angle),
          y + radius * math.sin(angle),
        );
        if (i == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      path.close();
      canvas.drawPath(
        path,
        outline
            ? line
            : (Paint()..color = const Color(0xFF94D2FA).withValues(alpha: .22)),
      );
    }

    cross(202, 189, 104);
    cross(307, 242, 50);
    cross(762, 355, 74);
    hexagon(9, 166, 74, outline: true);
    hexagon(102, 262, 57);
    hexagon(173, 313, 26);
    hexagon(3, 360, 50, outline: true);
    hexagon(677, 55, 41);
    hexagon(751, 113, 57);
    hexagon(815, 20, 69, outline: true);
    hexagon(871, 111, 62, outline: true);
    hexagon(841, 432, 40);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MedicalBackgroundPainter oldDelegate) => false;
}
