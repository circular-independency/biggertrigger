import 'package:flutter/material.dart';

class CyberColors {
  static const Color bgTop = Color(0xFF0A101A);
  static const Color bgBottom = Color(0xFF02070E);
  static const Color panel = Color(0xFF0E1522);
  static const Color panelSoft = Color(0xCC121B2A);
  static const Color line = Color(0xFF6EE7FF);
  static const Color cyan = Color(0xFF5FE7FF);
  static const Color lime = Color(0xFF9CFF1A);
  static const Color amber = Color(0xFFFFC44D);
  static const Color textPrimary = Color(0xFFE8EEF7);
  static const Color textMuted = Color(0xFF8CA1BD);
}

class CyberText {
  static const TextStyle title = TextStyle(
    fontSize: 34,
    fontWeight: FontWeight.w800,
    color: CyberColors.textPrimary,
    letterSpacing: 1.2,
  );

  static const TextStyle section = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: CyberColors.cyan,
    letterSpacing: 1.0,
  );

  static const TextStyle value = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w800,
    color: CyberColors.textPrimary,
  );

  static const TextStyle body = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: CyberColors.textPrimary,
  );

  static const TextStyle tiny = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: CyberColors.textMuted,
    letterSpacing: 1.1,
  );
}

class CyberShadows {
  static const List<BoxShadow> glow = <BoxShadow>[
    BoxShadow(
      color: Color(0x552DDAFF),
      blurRadius: 16,
      spreadRadius: 1,
    ),
  ];
}
