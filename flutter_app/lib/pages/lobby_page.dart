import 'dart:async';
import 'package:flutter/material.dart';

import '../components/hud_background.dart';
import '../components/hud_header.dart';
import '../components/lobby_action_bar.dart';
import '../components/lobby_mission_card.dart';
import '../components/lobby_operatives_panel.dart';
import '../logic/lobby_manager.dart';
import '../logic/socket_manager.dart';
import '../main.dart';

class LobbyPage extends StatefulWidget {
  LobbyPage({
    super.key,
    LobbyManager? lobbyManager,
    SocketManager? socketManager,
  }) : lobbyManager = lobbyManager ?? LobbyManager(),
       socketManager = socketManager ?? SocketManager();

  final LobbyManager lobbyManager;
  final SocketManager socketManager;

  @override
  State<LobbyPage> createState() => _LobbyPageState();
}

class _LobbyPageState extends State<LobbyPage> {
  bool _isConnecting = true;
  bool _didNavigateAway = false;
  StreamSubscription<Map<String, SocketLobbyUser>>? _usersSubscription;
  StreamSubscription<String>? _messagesSubscription;

  @override
  void initState() {
    super.initState();
    _usersSubscription = widget.socketManager.usersUpdates.listen(
      (Map<String, SocketLobbyUser> users) {
        if (!mounted) {
          return;
        }
        setState(() {
          widget.lobbyManager.updatePlayersFromSocket(users);
        });
      },
    );
    _messagesSubscription = widget.socketManager.messages.listen(
      (_) {},
      onError: (Object error) {
        _goToHomeWithError(error);
      },
    );
    _connectSocket();
  }

  Future<void> _connectSocket() async {
    try {
      await widget.socketManager.connect();
      if (!mounted) {
        return;
      }
      setState(() {
        _isConnecting = false;
      });
    } catch (error) {
      _goToHomeWithError(error);
    }
  }

  void _goToHomeWithError(Object error) {
    if (!mounted || _didNavigateAway) {
      return;
    }
    _didNavigateAway = true;
    Navigator.pushNamedAndRemoveUntil(
      context,
      DragonHackApp.mainMenuRoute,
      (Route<dynamic> route) => false,
      arguments: 'Socket connection failed: $error',
    );
  }

  @override
  void dispose() {
    _messagesSubscription?.cancel();
    _usersSubscription?.cancel();
    widget.socketManager.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isConnecting) {
      return const Scaffold(
        body: HudBackground(
          child: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

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
