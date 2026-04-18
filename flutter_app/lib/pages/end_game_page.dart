import 'dart:async';

import 'package:flutter/material.dart';

import '../components/cyber_panel.dart';
import '../components/cyber_theme.dart';
import '../components/hud_background.dart';
import '../logic/sound_manager.dart';
import '../main.dart';

class EndGamePage extends StatelessWidget {
  const EndGamePage({super.key, this.username});

  final String? username;

  @override
  Widget build(BuildContext context) {
    final String player =
        (username == null || username!.trim().isEmpty) ? 'OPERATIVE' : username!.trim();

    return Scaffold(
      body: HudBackground(
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: CyberPanel(
                  borderRadius: 0,
                  glow: true,
                  borderColor: const Color(0x88FF5A66),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      const Text(
                        '[MISSION_STATUS]',
                        style: TextStyle(
                          color: Color(0xFFFF6C75),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'ELIMINATED',
                        style: TextStyle(
                          color: CyberColors.textPrimary,
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$player HP reached 0.',
                        style: const TextStyle(
                          color: CyberColors.textMuted,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: CyberColors.cyan,
                          foregroundColor: Colors.black,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.zero,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () {
                          unawaited(SoundManager.playButton());
                          Navigator.pushNamedAndRemoveUntil(
                            context,
                            DragonHackApp.mainMenuRoute,
                            (Route<dynamic> route) => false,
                          );
                        },
                        child: const Text(
                          'RETURN HOME',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
