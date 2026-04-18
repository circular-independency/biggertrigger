import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../components/hud_background.dart';
import '../components/hud_header.dart';
import '../components/lobby_action_bar.dart';
import '../components/lobby_mission_card.dart';
import '../components/lobby_operatives_panel.dart';
import '../logic/game_models.dart';
import '../logic/game_session_controller.dart';
import '../logic/lobby_manager.dart';
import '../main.dart';
import 'registration_page.dart';

class LobbyPage extends StatefulWidget {
  const LobbyPage({
    super.key,
    required this.controller,
  });

  final GameSessionController controller;

  @override
  State<LobbyPage> createState() => _LobbyPageState();
}

class _LobbyPageState extends State<LobbyPage> {
  bool _isRoutingToGame = false;
  String? _lastShownError;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleControllerUpdate);
    unawaited(_connectIfNeeded());
  }

  Future<void> _connectIfNeeded() async {
    try {
      await widget.controller.connect();
    } catch (error) {
      if (!mounted) {
        return;
      }
      Navigator.pushNamedAndRemoveUntil(
        context,
        DragonHackApp.mainMenuRoute,
        (Route<dynamic> route) => false,
        arguments: 'Socket connection failed: $error',
      );
    }
  }

  void _handleControllerUpdate() {
    if (!mounted) {
      return;
    }

    final String? error = widget.controller.lastError;
    if (widget.controller.connectionState == SessionConnectionState.error &&
        widget.controller.phase != MatchPhase.inGame &&
        error != null &&
        error != _lastShownError) {
      _lastShownError = error;
      Navigator.pushNamedAndRemoveUntil(
        context,
        DragonHackApp.mainMenuRoute,
        (Route<dynamic> route) => false,
        arguments: error,
      );
      return;
    }

    if (widget.controller.phase == MatchPhase.inGame && !_isRoutingToGame) {
      _isRoutingToGame = true;
      Navigator.pushReplacementNamed(context, DragonHackApp.gameRoute);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerUpdate);
    super.dispose();
  }

  Future<void> _openRegistrationFlow() async {
    final List<Uint8List>? images =
        await Navigator.of(context).push<List<Uint8List>>(
          MaterialPageRoute<List<Uint8List>>(
            builder: (BuildContext context) => const RegistrationPage(),
          ),
        );

    if (!mounted || images == null || images.isEmpty) {
      return;
    }

    try {
      await widget.controller.registerAndReady(images);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF9B1C25),
            content: Text('Registration failed: $error'),
          ),
        );
    }
  }

  Future<void> _leaveLobby() async {
    await widget.controller.disconnect();
    if (!mounted) {
      return;
    }

    Navigator.pushNamedAndRemoveUntil(
      context,
      DragonHackApp.mainMenuRoute,
      (Route<dynamic> route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (BuildContext context, Widget? child) {
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (bool didPop, Object? result) {
            if (didPop) {
              return;
            }
            unawaited(_leaveLobby());
          },
          child: _buildScaffold(),
        );
      },
    );
  }

  Widget _buildScaffold() {
    final bool isConnecting =
        widget.controller.connectionState == SessionConnectionState.connecting &&
        widget.controller.players.isEmpty;

    if (isConnecting) {
      return const Scaffold(
        body: HudBackground(
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final List<LobbyPlayer> lobbyPlayers = _buildLobbyPlayers();
    final _LobbyActionState actionState = _buildActionState();

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
                      signalLabel: 'SERVER_LINK',
                      signalValue: widget.controller.serverUrl,
                      avatarIcon: Icons.person,
                    ),
                    SizedBox(height: gap * 1.2),
                    LobbyMissionCard(
                      missionLabel: 'MISSION_ID // HOST',
                      code: widget.controller.lobbyCode,
                      squad: widget.controller.hostId ?? 'AWAITING_HOST',
                    ),
                    SizedBox(height: gap * 1.0),
                    Text(
                      'CONNECTED ${widget.controller.players.length}/4 // '
                      'READY ${widget.controller.players.where((SessionPlayer player) => player.ready).length}/${widget.controller.players.length}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF9CFF1A),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                      ),
                    ),
                    SizedBox(height: gap * 1.1),
                    Expanded(
                      child: LobbyOperativesPanel(
                        players: lobbyPlayers,
                        activeCount: widget.controller.players.length,
                        totalSlots: 4,
                      ),
                    ),
                    SizedBox(height: gap * 1.0),
                    Text(
                      widget.controller.hasLocalRegistration
                          ? 'LOCAL EMBEDDINGS: ${widget.controller.localEmbeddingCount} // '
                              'SYNCED PLAYERS: ${widget.controller.syncedEmbeddingIds.length}'
                          : 'Capture 3 registration photos before entering the match.',
                      style: const TextStyle(
                        color: Color(0xFF8CA1BD),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: gap * 0.8),
                    LobbyActionBar(
                      primaryLabel: actionState.primary,
                      secondaryLabel: actionState.secondary,
                      icon: actionState.icon,
                      accent: actionState.accent,
                      isEnabled: actionState.enabled,
                      onTap: actionState.onTap,
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

  List<LobbyPlayer> _buildLobbyPlayers() {
    final List<LobbyPlayer> players = widget.controller.players
        .map(
          (SessionPlayer player) => LobbyPlayer.fromSessionPlayer(
            player,
            isLocalPlayer: player.id == widget.controller.username,
          ),
        )
        .toList(growable: true);

    while (players.length < 4) {
      players.add(LobbyPlayer.placeholder(players.length));
    }

    return players;
  }

  _LobbyActionState _buildActionState() {
    if (widget.controller.isRegistering) {
      return _LobbyActionState(
        primary: 'SYNCING IDENTITY',
        secondary: 'PLEASE WAIT',
        accent: const Color(0xFFFFC44D),
        icon: Icons.sync,
        enabled: false,
        onTap: () {},
      );
    }

    if (!widget.controller.hasLocalRegistration) {
      return _LobbyActionState(
        primary: 'CAPTURE & READY',
        secondary: '3 REG PHOTOS',
        accent: const Color(0xFF5FE7FF),
        icon: Icons.camera_alt_rounded,
        enabled: widget.controller.canRegister,
        onTap: _openRegistrationFlow,
      );
    }

    if (widget.controller.canStartGame) {
      return _LobbyActionState(
        primary: 'START MATCH',
        secondary: 'HOST CONTROL',
        accent: const Color(0xFF9CFF1A),
        icon: Icons.play_arrow_rounded,
        enabled: true,
        onTap: () {
          unawaited(widget.controller.startGame());
        },
      );
    }

    return _LobbyActionState(
      primary: widget.controller.isLobbyHost ? 'WAITING FOR TEAM' : 'READY // STANDBY',
      secondary: widget.controller.isLobbyHost ? 'NEED ALL READY' : 'HOST STARTS MATCH',
      accent: const Color(0xFFFFC44D),
      icon: Icons.hourglass_top_rounded,
      enabled: false,
      onTap: () {},
    );
  }
}

class _LobbyActionState {
  const _LobbyActionState({
    required this.primary,
    required this.secondary,
    required this.accent,
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final String primary;
  final String secondary;
  final Color accent;
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
}
