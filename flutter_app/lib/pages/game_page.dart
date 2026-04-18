import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../components/cyber_theme.dart';
import '../logic/game_models.dart';
import '../logic/game_session_controller.dart';
import '../main.dart';

class GamePage extends StatefulWidget {
  const GamePage({
    super.key,
    required this.controller,
  });

  final GameSessionController controller;

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  String? _lastShownError;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleControllerUpdate);
    unawaited(_configureGameScreen());
  }

  Future<void> _configureGameScreen() async {
    try {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      await widget.controller.startVisionPreview();
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF9B1C25),
            content: Text('Failed to start native camera preview: $error'),
          ),
        );
    }
  }

  void _handleControllerUpdate() {
    if (!mounted) {
      return;
    }

    if (widget.controller.connectionState == SessionConnectionState.error &&
        widget.controller.lastError != null &&
        widget.controller.lastError != _lastShownError) {
      _lastShownError = widget.controller.lastError;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF9B1C25),
            content: Text(widget.controller.lastError!),
          ),
        );
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerUpdate);
    unawaited(widget.controller.stopVisionPreview());
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    unawaited(SystemChrome.setPreferredOrientations(DeviceOrientation.values));
    super.dispose();
  }

  Future<bool> _confirmExit() async {
    final bool? shouldQuit = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 28),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: CyberColors.panel,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: CyberColors.cyan.withValues(alpha: 0.45), width: 1.2),
              boxShadow: const <BoxShadow>[
                BoxShadow(color: Color(0x662DDAFF), blurRadius: 18),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  '[MISSION_ABORT]',
                  style: TextStyle(
                    color: CyberColors.amber,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Quit Match?',
                  style: TextStyle(
                    color: CyberColors.textPrimary,
                    fontSize: 24 / 1.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'This will disconnect you from the current lobby.',
                  style: TextStyle(
                    color: CyberColors.textMuted,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: CyberColors.cyan.withValues(alpha: 0.65)),
                          foregroundColor: CyberColors.cyan,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.zero,
                          ),
                        ),
                        onPressed: () {
                          Navigator.of(context).pop(false);
                        },
                        child: const Text('CANCEL'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF9B1C25),
                          foregroundColor: Colors.white,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.zero,
                          ),
                        ),
                        onPressed: () {
                          Navigator.of(context).pop(true);
                        },
                        child: const Text('QUIT'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    return shouldQuit ?? false;
  }

  Future<void> _exitMatch() async {
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
          onPopInvokedWithResult: (bool didPop, Object? result) async {
            if (didPop) {
              return;
            }

            final bool shouldQuit = await _confirmExit();
            if (shouldQuit && mounted) {
              unawaited(_exitMatch());
            }
          },
          child: Scaffold(
            body: _buildBody(),
          ),
        );
      },
    );
  }

  Widget _buildBody() {
    if (widget.controller.isPreviewStarting || widget.controller.previewTextureId == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final SessionPlayer? localPlayer = widget.controller.localPlayer;
    final int hpPercent = localPlayer?.hp ?? 0;

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Container(color: Colors.black),
        Center(
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                Texture(textureId: widget.controller.previewTextureId!),
                IgnorePointer(
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: <Color>[Color(0x44000000), Color(0x66000000)],
                      ),
                    ),
                  ),
                ),
                const IgnorePointer(child: _ScanlineOverlay()),
                const IgnorePointer(child: _CrosshairOverlay()),
              ],
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: _IntegrityBlock(
                        hpPercent: hpPercent,
                        playerName: widget.controller.username,
                      ),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 280,
                      child: _RosterPanel(
                        players: widget.controller.players,
                        localPlayerId: widget.controller.username,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Expanded(
                      child: _NotificationStack(
                        notifications: widget.controller.notifications,
                      ),
                    ),
                    const SizedBox(width: 14),
                    _FireButton(
                      enabled: widget.controller.canShoot,
                      isBusy: widget.controller.isShooting,
                      onTap: () {
                        unawaited(widget.controller.shoot());
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (widget.controller.phase != MatchPhase.finished &&
            widget.controller.isLocalEliminated)
          const _EndOverlay(
            title: 'ELIMINATED',
            subtitle: 'You are out. Stay in the lobby until the winner is decided.',
            accent: Color(0xFFFF4C52),
          ),
        if (widget.controller.phase == MatchPhase.finished)
          _EndOverlay(
            title: widget.controller.isLocalWinner ? 'VICTORY' : 'MATCH OVER',
            subtitle: widget.controller.isLocalWinner
                ? 'You are the last player standing.'
                : 'Winner: ${widget.controller.winnerId ?? 'UNKNOWN'}',
            accent: widget.controller.isLocalWinner
                ? CyberColors.lime
                : const Color(0xFFFFC44D),
          ),
      ],
    );
  }
}

class _IntegrityBlock extends StatelessWidget {
  const _IntegrityBlock({
    required this.hpPercent,
    required this.playerName,
  });

  final int hpPercent;
  final String playerName;

  @override
  Widget build(BuildContext context) {
    const int totalBars = 10;
    final int activeBars = ((hpPercent / 100) * totalBars).round().clamp(0, totalBars);

    return Container(
      width: 480,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: CyberColors.panelSoft.withValues(alpha: 0.88),
        border: Border.all(color: CyberColors.line.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            playerName,
            style: const TextStyle(
              color: CyberColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              const Text(
                'HP',
                style: TextStyle(
                  color: CyberColors.cyan,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Row(
                  children: List<Widget>.generate(
                    totalBars,
                    (int index) => Expanded(
                      child: Container(
                        height: 11,
                        margin: EdgeInsets.only(right: index == totalBars - 1 ? 0 : 4),
                        decoration: BoxDecoration(
                          color: index < activeBars
                              ? CyberColors.lime
                              : CyberColors.lime.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '$hpPercent%',
                style: const TextStyle(
                  color: CyberColors.lime,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RosterPanel extends StatelessWidget {
  const _RosterPanel({
    required this.players,
    required this.localPlayerId,
  });

  final List<SessionPlayer> players;
  final String localPlayerId;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CyberColors.panelSoft.withValues(alpha: 0.88),
        border: Border.all(color: CyberColors.line.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Text(
            'OPERATIVES',
            style: TextStyle(
              color: CyberColors.cyan,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 10),
          ...players.map((SessionPlayer player) {
            final bool isLocal = player.id == localPlayerId;
            final Color accent = !player.alive
                ? const Color(0xFFFF4C52)
                : isLocal
                ? CyberColors.lime
                : CyberColors.cyan;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          isLocal ? '${player.id} // YOU' : player.id,
                          style: const TextStyle(
                            color: CyberColors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        player.alive ? '${player.hp} HP' : 'OUT',
                        style: TextStyle(
                          color: accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      minHeight: 7,
                      value: (player.hp.clamp(0, 100)) / 100,
                      backgroundColor: Colors.white10,
                      valueColor: AlwaysStoppedAnimation<Color>(accent),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _NotificationStack extends StatelessWidget {
  const _NotificationStack({required this.notifications});

  final List<SessionNotification> notifications;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: notifications
              .map(
                (SessionNotification notification) =>
                    _NotificationCard(notification: notification),
              )
              .toList(growable: false),
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.notification});

  final SessionNotification notification;

  @override
  Widget build(BuildContext context) {
    final Color accent = switch (notification.tone) {
      NotificationTone.success => CyberColors.lime,
      NotificationTone.warning => const Color(0xFFFFC44D),
      NotificationTone.danger => const Color(0xFFFF4C52),
      NotificationTone.info => CyberColors.cyan,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        border: Border(left: BorderSide(color: accent, width: 3)),
        boxShadow: <BoxShadow>[
          BoxShadow(color: accent.withValues(alpha: 0.25), blurRadius: 16),
        ],
      ),
      child: Text(
        notification.message,
        style: TextStyle(
          color: accent,
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.7,
        ),
      ),
    );
  }
}

class _FireButton extends StatelessWidget {
  const _FireButton({
    required this.enabled,
    required this.isBusy,
    required this.onTap,
  });

  final bool enabled;
  final bool isBusy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: enabled && !isBusy ? onTap : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: enabled ? const Color(0xFFFF4C52) : Colors.white24,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      icon: const Icon(Icons.gps_fixed_rounded),
      label: Text(isBusy ? 'FIRING...' : 'FIRE'),
    );
  }
}

class _CrosshairOverlay extends StatelessWidget {
  const _CrosshairOverlay();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 78,
        height: 78,
        child: Stack(
          alignment: Alignment.center,
          children: const <Widget>[
            _CrosshairLine(width: 2, height: 30),
            _CrosshairLine(width: 30, height: 2),
            DecoratedBox(
              decoration: BoxDecoration(color: CyberColors.cyan, shape: BoxShape.circle),
              child: SizedBox(width: 8, height: 8),
            ),
          ],
        ),
      ),
    );
  }
}

class _CrosshairLine extends StatelessWidget {
  const _CrosshairLine({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: CyberColors.cyan,
        boxShadow: <BoxShadow>[BoxShadow(color: Color(0xAA5FE7FF), blurRadius: 8)],
      ),
      child: SizedBox(width: width, height: height),
    );
  }
}

class _ScanlineOverlay extends StatelessWidget {
  const _ScanlineOverlay();

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.12,
      child: CustomPaint(
        painter: _ScanlinePainter(),
      ),
    );
  }
}

class _ScanlinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const double spacing = 4;
    final Paint paint = Paint()
      ..color = CyberColors.cyan.withValues(alpha: 0.25)
      ..strokeWidth = 1;

    for (double y = 0; y <= size.height; y += spacing) {
      canvas.drawLine(Offset.zero.translate(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _EndOverlay extends StatelessWidget {
  const _EndOverlay({
    required this.title,
    required this.subtitle,
    required this.accent,
  });

  final String title;
  final String subtitle;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.55),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            decoration: BoxDecoration(
              color: CyberColors.panelSoft.withValues(alpha: 0.9),
              border: Border.all(color: accent.withValues(alpha: 0.8), width: 1.5),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  title,
                  style: TextStyle(
                    color: accent,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: CyberColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
