import 'package:flutter/material.dart';

import 'cyber_panel.dart';
import 'cyber_theme.dart';

class LobbyActionBar extends StatelessWidget {
  const LobbyActionBar({
    super.key,
    required this.primaryLabel,
    required this.secondaryLabel,
    required this.icon,
    required this.accent,
    required this.isEnabled,
    required this.onTap,
  });

  final String primaryLabel;
  final String secondaryLabel;
  final IconData icon;
  final Color accent;
  final bool isEnabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color resolvedAccent = isEnabled
        ? accent
        : CyberColors.textMuted.withValues(alpha: 0.45);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: _chip('[LOCAL_COMM]', CyberColors.cyan),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _chip('[EMBED_SYNC]', CyberColors.lime),
            ),
          ],
        ),
        const SizedBox(height: 4),
        CyberPanel(
          padding: EdgeInsets.zero,
          borderRadius: 0,
          borderColor: resolvedAccent.withValues(alpha: 0.7),
          glow: isEnabled,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: isEnabled ? onTap : null,
              child: Ink(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: <Color>[
                      resolvedAccent.withValues(alpha: 0.95),
                      resolvedAccent.withValues(alpha: 0.65),
                    ],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: Row(
                    children: <Widget>[
                      Icon(
                        icon,
                        color: isEnabled ? Colors.black : Colors.black.withValues(alpha: 0.5),
                        size: 32,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          primaryLabel,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isEnabled
                                ? Colors.black
                                : Colors.black.withValues(alpha: 0.5),
                            fontSize: 30 / 1.5,
                            fontWeight: FontWeight.w800,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                      Text(
                        secondaryLabel,
                        style: TextStyle(
                          color: isEnabled
                              ? Colors.black.withValues(alpha: 0.72)
                              : Colors.black.withValues(alpha: 0.45),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      color: CyberColors.panelSoft,
      child: Text(
        text,
        style: CyberText.tiny.copyWith(color: color),
      ),
    );
  }
}
