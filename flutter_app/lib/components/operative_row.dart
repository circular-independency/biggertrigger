import 'package:flutter/material.dart';

import 'cyber_theme.dart';

class OperativeRow extends StatelessWidget {
  const OperativeRow({
    super.key,
    required this.name,
    required this.statusText,
    required this.statusColor,
    required this.markerColor,
    this.placeholder = false,
  });

  final String name;
  final String statusText;
  final Color statusColor;
  final Color markerColor;
  final bool placeholder;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: CyberColors.line.withValues(alpha: 0.10),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: <Widget>[
          Container(width: 5, height: 30, color: markerColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                color: placeholder
                    ? CyberColors.textMuted.withValues(alpha: 0.3)
                    : CyberColors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w700,
                fontStyle: placeholder ? FontStyle.italic : FontStyle.normal,
              ),
            ),
          ),
          Text(
            statusText,
            style: TextStyle(
              color: statusColor,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              fontStyle: placeholder ? FontStyle.italic : FontStyle.normal,
            ),
          ),
          const SizedBox(width: 8),
          if (!placeholder)
            Container(
              width: 11,
              height: 11,
              decoration: BoxDecoration(
                color: statusColor,
                shape: BoxShape.circle,
                boxShadow: <BoxShadow>[
                  BoxShadow(color: statusColor.withValues(alpha: 0.7), blurRadius: 8),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
