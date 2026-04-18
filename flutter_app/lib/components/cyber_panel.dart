import 'package:flutter/material.dart';

import 'cyber_theme.dart';

class CyberPanel extends StatelessWidget {
  const CyberPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.borderRadius = 10,
    this.borderColor,
    this.backgroundColor,
    this.glow = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final Color? borderColor;
  final Color? backgroundColor;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? CyberColors.panelSoft,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: borderColor ?? CyberColors.line.withValues(alpha: 0.18),
          width: 1,
        ),
        boxShadow: glow ? CyberShadows.glow : null,
      ),
      child: Padding(
        padding: padding,
        child: child,
      ),
    );
  }
}
