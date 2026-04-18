import 'package:flutter/material.dart';

import 'cyber_panel.dart';
import 'cyber_theme.dart';

class CyberInputField extends StatelessWidget {
  const CyberInputField({
    super.key,
    required this.controller,
    required this.label,
    this.errorText,
    this.hint,
  });

  final TextEditingController controller;
  final String label;
  final String? errorText;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return CyberPanel(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      borderRadius: 8,
      borderColor: errorText == null
          ? CyberColors.cyan.withValues(alpha: 0.4)
          : const Color(0xFFFF4C52),
      child: TextField(
        controller: controller,
        cursorColor: CyberColors.cyan,
        style: const TextStyle(
          color: CyberColors.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
        decoration: InputDecoration(
          isDense: true,
          border: InputBorder.none,
          labelText: label,
          labelStyle: const TextStyle(
            color: CyberColors.cyan,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
          hintText: hint,
          hintStyle: TextStyle(color: CyberColors.textMuted.withValues(alpha: 0.7)),
          errorText: errorText,
          errorStyle: const TextStyle(color: Color(0xFFFF6A6A), fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
