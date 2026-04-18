import 'package:flutter/material.dart';

import 'cyber_panel.dart';
import 'cyber_theme.dart';

class SettingsProfileCard extends StatelessWidget {
  const SettingsProfileCard({
    super.key,
    required this.username,
    required this.signalText,
    required this.rankText,
    this.avatarIcon = Icons.person,
    this.progress = 0.76,
  });

  final String username;
  final String signalText;
  final String rankText;
  final IconData avatarIcon;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return CyberPanel(
      glow: true,
      borderRadius: 12,
      borderColor: CyberColors.line.withValues(alpha: 0.28),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _avatarBox(),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  username,
                  style: TextStyle(
                    color: CyberColors.lime,
                    fontSize: 24 ,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: <Widget>[const Text(
                      'RANK_CLASS',
                      style: TextStyle(
                        color: CyberColors.cyan,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _rankChip(rankText),
                  ],
                ),
                const SizedBox(height: 10),
                _progressBar(progress.clamp(0, 1)),
                const SizedBox(height: 8),
                Text(
                  signalText,
                  style: const TextStyle(
                    color: CyberColors.textMuted,
                    fontSize: 16 / 1.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatarBox() {
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        Container(
          width: 80,
          height: 96,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: CyberColors.lime.withValues(alpha: 0.8), width: 1.2),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[Color(0xFF1A2E3E), Color(0xFF101A2A)],
            ),
          ),
          child: Center(
            child: Icon(
              avatarIcon,
              color: Colors.white,
            ),
          ),
        ),
        Positioned(
          bottom: -9,
          left: 24,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            color: CyberColors.lime,
            child: const Text(
              'LVL 42',
              style: TextStyle(
                color: Colors.black,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _rankChip(String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: CyberColors.cyan.withValues(alpha: 0.7)),
        color: CyberColors.panel,
      ),
      child: Text(
        value,
        style: const TextStyle(
          color: CyberColors.cyan,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _progressBar(double value) {
    return SizedBox(
      height: 7,
      child: Stack(
        children: <Widget>[
          Container(color: CyberColors.textMuted.withValues(alpha: 0.18)),
          FractionallySizedBox(
            widthFactor: value,
            child: Container(color: CyberColors.lime),
          ),
        ],
      ),
    );
  }
}
