import 'package:flutter/material.dart';

import '../components/commander_card.dart';
import '../components/cyber_theme.dart';
import '../components/deploy_panel.dart';
import '../components/hud_background.dart';
import '../components/hud_header.dart';
import '../components/info_tile.dart';
import '../components/threat_tag.dart';
import '../main.dart';

class MainMenuPage extends StatelessWidget {
  const MainMenuPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: HudBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final double pad = constraints.maxWidth * 0.06;
              final double gap = constraints.maxHeight * 0.02;

              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: pad, vertical: gap),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        HudHeader(
                          onSettingsTap: () {
                            Navigator.pushNamed(context, DragonHackApp.settingsRoute);
                          },
                        ),
                        SizedBox(height: gap),
                        SizedBox(
                          height: constraints.maxHeight * 0.47,
                          child: Stack(
                            children: <Widget>[
                              Align(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 22),
                                  child: DeployPanel(
                                    onDeployTap: () {
                                      Navigator.pushNamed(context, DragonHackApp.lobbyRoute);
                                    },
                                  ),
                                ),
                              ),
                              const Positioned(
                                right: 0,
                                top: 18,
                                child: ThreatTag(),
                              ),
                              Positioned(
                                left: 0,
                                bottom: 24,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: const <Widget>[
                                    Text('OBJ_LOC_XY', style: CyberText.section),
                                    SizedBox(height: 2),
                                    Text(
                                      '42.9 / 18.4',
                                      style: TextStyle(
                                        color: CyberColors.textPrimary,
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: gap),
                        Row(
                          children: const <Widget>[
                            Expanded(
                              child: InfoTile(
                                icon: Icons.military_tech_outlined,
                                title: 'LOADOUT',
                                value: 'M4_SPEAR_V2',
                                accentColor: CyberColors.cyan,
                              ),
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: InfoTile(
                                icon: Icons.track_changes_rounded,
                                title: 'INTEL',
                                value: 'SECURE_DATA',
                                accentColor: CyberColors.amber,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: gap),
                        const CommanderCard(
                          commanderName: 'COMMANDER_01',
                          levelText: 'LVL 42 // ELITE',
                          rankLabel: 'XP_NEXT_RANK',
                          progressText: '4,820 / 5,000',
                          progress: 0.964,
                        ),
                        SizedBox(height: gap),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
