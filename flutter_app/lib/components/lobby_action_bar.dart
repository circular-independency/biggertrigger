import 'dart:async';

import 'package:flutter/material.dart';

import 'cyber_panel.dart';
import 'cyber_theme.dart';
import '../logic/sound_manager.dart';

class LobbyActionBar extends StatelessWidget {
  const LobbyActionBar({
    super.key,
    required this.isReady,
    required this.onReadyTap,
    required this.onStartTap,
    this.startEnabled = true,
  });

  final bool isReady;
  final VoidCallback onReadyTap;
  final VoidCallback onStartTap;
  final bool startEnabled;

  @override
  Widget build(BuildContext context) {
    final bool isStartDisabled = isReady && !startEnabled;
    final Color accent = isReady
        ? (isStartDisabled ? CyberColors.textMuted : CyberColors.lime)
        : CyberColors.cyan;
    final String label = isReady ? 'START' : 'READY UP';
    final Color actionFg = isReady
        ? (isStartDisabled ? CyberColors.panel : Colors.black)
        : const Color(0xFF145065);
    final Color textFg = isReady
        ? (isStartDisabled ? CyberColors.panel : Colors.black)
        : const Color(0xFF165873);

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
              onTap: isReady
                  ? (startEnabled
                        ? () {
                            unawaited(SoundManager.playButton());
                            onStartTap();
                          }
                        : null)
                  : () {
                      unawaited(SoundManager.playButton());
                      onReadyTap();
                    },
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
                        color: actionFg,
                        size: 32,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          label,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: textFg,
                            fontSize: 30 / 1.5,
                            fontWeight: FontWeight.w800,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: actionFg,
                        size: 34,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'LVL 42 // ELITE',
                        style: TextStyle(
                          color: isReady
                              ? (isStartDisabled
                                    ? CyberColors.panel.withValues(alpha: 0.7)
                                    : Colors.black.withValues(alpha: 0.7))
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
