import 'package:flutter/material.dart';

import '../components/hud_background.dart';
import '../components/hud_header.dart';
import '../components/lobby_action_bar.dart';
import '../components/lobby_mission_card.dart';
import '../components/lobby_operatives_panel.dart';
import '../logic/lobby_manager.dart';
import '../main.dart';

class LobbyPage extends StatefulWidget {
  LobbyPage({super.key, LobbyManager? lobbyManager})
    : lobbyManager = lobbyManager ?? LobbyManager();

  final LobbyManager lobbyManager;

  @override
  State<LobbyPage> createState() => _LobbyPageState();
}

class _LobbyPageState extends State<LobbyPage> {
  @override
  Widget build(BuildContext context) {
    final LobbyStatus status = widget.lobbyManager.getCurrentStatus();
    final bool isReady = status == LobbyStatus.active;

    return Scaffold(
      body: HudBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final double pad = constraints.maxWidth * 0.05;
              final double gap = constraints.maxHeight * 0.014;

              return Padding(
                padding: EdgeInsets.symmetric(horizontal: pad, vertical: gap),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    HudHeader(
                      onSettingsTap: () {
                        Navigator.pushNamed(context, DragonHackApp.settingsRoute);
                      },
                      signalLabel: 'SIGNAL_STRENGTH',
                      signalValue: '98% // STABLE',
                      avatarIcon: Icons.person,
                    ),
                    SizedBox(height: gap * 1.2),
                    const LobbyMissionCard(),
                    SizedBox(height: gap * 1.4),
                    Expanded(
                      child: LobbyOperativesPanel(
                        players: widget.lobbyManager.getActivePlayers(),
                        activeCount: widget.lobbyManager.activeOperativesCount,
                        totalSlots: widget.lobbyManager.totalOperativeSlots,
                      ),
                    ),
                    SizedBox(height: gap * 1.2),
                    LobbyActionBar(
                      isReady: isReady,
                      onReadyTap: () {
                        setState(() {
                          widget.lobbyManager.setReady();
                        });
                      },
                      onStartTap: () {
                        Navigator.pushNamed(context, DragonHackApp.gameRoute);
                      },
                    ),
                    SizedBox(height: gap * 0.4),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
