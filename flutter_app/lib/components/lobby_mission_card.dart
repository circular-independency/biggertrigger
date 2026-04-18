import 'package:flutter/material.dart';

import 'cyber_panel.dart';
import 'cyber_theme.dart';

class LobbyMissionCard extends StatelessWidget {
  const LobbyMissionCard({
    super.key,
    this.title = 'SQUAD ASSEMBLY',
    this.missionLabel = 'MISSION_ID // ROOM_CODE',
    this.code = 'X-99 //',
    this.squad = 'ALPHA-7',
  });

  final String title;
  final String missionLabel;
  final String code;
  final String squad;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: CyberColors.textPrimary,
            fontSize: 28,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        Stack(
          alignment: Alignment.center,
          children: <Widget>[
            const Positioned(left: 0, child: _Rail()),
            const Positioned(right: 0, child: _Rail()),
            CyberPanel(
              borderRadius: 0,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
              child: Column(
                children: <Widget>[
                  Text(missionLabel, style: CyberText.section),
                  const SizedBox(height: 8),
                  Text(
                    code,
                    style: const TextStyle(
                      color: CyberColors.textPrimary,
                      fontSize: 48 / 1.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                  Text(
                    squad,
                    style: const TextStyle(
                      color: CyberColors.textPrimary,
                      fontSize: 48 / 1.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Rail extends StatelessWidget {
  const _Rail();

  @override
  Widget build(BuildContext context) {
    return Container(width: 4, height: 128, color: CyberColors.cyan);
  }
}
