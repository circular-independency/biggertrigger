import 'package:flutter/material.dart';

import 'cyber_theme.dart';

class HudBackground extends StatelessWidget {
  const HudBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[CyberColors.bgTop, CyberColors.bgBottom],
            ),
          ),
        ),
        IgnorePointer(
          child: Opacity(
            opacity: 0.18,
            child: CustomPaint(painter: _ScanlinePainter()),
          ),
        ),
        IgnorePointer(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: CyberColors.line.withValues(alpha: 0.15), width: 1),
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _ScanlinePainter extends CustomPainter {
  const _ScanlinePainter();

  @override
  void paint(Canvas canvas, Size size) {
    const double spacing = 5;
    final Paint paint = Paint()
      ..color = CyberColors.cyan.withValues(alpha: 0.18)
      ..strokeWidth = 1;

    for (double y = 0; y <= size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
