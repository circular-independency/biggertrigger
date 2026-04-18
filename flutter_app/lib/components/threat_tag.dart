import 'package:flutter/material.dart';

import 'cyber_theme.dart';

class ThreatTag extends StatelessWidget {
  const ThreatTag({
    super.key,
    this.title = 'THREAT_LEVEL',
    this.level = 'CRITICAL',
  });

  final String title;
  final String level;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xCC0D111A),
        border: Border.all(color: CyberColors.amber.withValues(alpha: 0.85), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(title, style: CyberText.tiny.copyWith(color: CyberColors.amber)),
          const SizedBox(height: 4),
          Text(
            level,
            style: const TextStyle(
              color: CyberColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
