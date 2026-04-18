import 'package:flutter/material.dart';

import 'cyber_panel.dart';
import 'cyber_theme.dart';

class LobbyActionBar extends StatelessWidget {
  const LobbyActionBar({
    super.key,
    required this.isReady,
    required this.onReadyTap,
    required this.onStartTap,
  });

  final bool isReady;
  final VoidCallback onReadyTap;
  final VoidCallback onStartTap;

  @override
  Widget build(BuildContext context) {
    final Color accent = isReady ? CyberColors.lime : CyberColors.cyan;
    final String label = isReady ? 'START' : 'READY UP';

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
              child: _chip('[INTEL_FEED]', CyberColors.lime),
            ),
          ],
        ),
        const SizedBox(height: 4),
        CyberPanel(
          padding: EdgeInsets.zero,
          borderRadius: 0,
          borderColor: accent.withValues(alpha: 0.7),
          glow: true,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: isReady ? onStartTap : onReadyTap,
              child: Ink(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: <Color>[
                      accent.withValues(alpha: 0.95),
                      accent.withValues(alpha: 0.65),
                    ],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: Row(
                    children: <Widget>[
                      Icon(
                        isReady ? Icons.play_arrow_rounded : Icons.bolt_rounded,
                        color: isReady ? Colors.black : const Color(0xFF145065),
                        size: 32,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          label,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isReady ? Colors.black : const Color(0xFF165873),
                            fontSize: 30 / 1.5,
                            fontWeight: FontWeight.w800,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: isReady ? Colors.black : const Color(0xFF145065),
                        size: 34,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'LVL 42 // ELITE',
                        style: TextStyle(
                          color: isReady
                              ? Colors.black.withValues(alpha: 0.7)
                              : const Color(0xFF145065).withValues(alpha: 0.65),
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
