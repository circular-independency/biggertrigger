import 'dart:async';

import 'package:flutter/material.dart';

import 'cyber_theme.dart';
import '../logic/sound_manager.dart';

class DeployPanel extends StatelessWidget {
  const DeployPanel({super.key, required this.onDeployTap});

  final VoidCallback onDeployTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: CyberColors.line, width: 2.5),
        color: CyberColors.panelSoft,
        boxShadow: CyberShadows.glow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            unawaited(SoundManager.playButton());
            onDeployTap();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 42, horizontal: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text('BATTLE', style: CyberText.title),
                const SizedBox(height: 12),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    _bar(CyberColors.lime),
                    const SizedBox(width: 4),
                    _bar(CyberColors.lime),
                    const SizedBox(width: 4),
                    _bar(CyberColors.lime.withValues(alpha: 0.35)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _bar(Color color) {
    return Container(
      width: 12,
      height: 5,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}
