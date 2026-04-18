import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../components/cyber_theme.dart';
import '../logic/vision_manager.dart';

class GamePage extends StatefulWidget {
  const GamePage({super.key, VisionManager? visionManager})
    : visionManager = visionManager ?? const VisionManager();

  final VisionManager visionManager;

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  int? _textureId;
  String? _error;
  bool _isLoading = true;
  bool _isUnsupported = false;

  final List<GameNotification> _notifications = <GameNotification>[];
  int _nextNotificationId = 0;

  bool get _isVisionPlatform =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    unawaited(_configureGameScreen());
  }

  Future<void> _configureGameScreen() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    await _initializePreview();

    if (mounted && !_isUnsupported) {
      showGameNotification('SECURE_LINK_ESTABLISHED', isGreen: true);
      Future<void>.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {
          showGameNotification('LOW_SIGNAL_ZONE_DETECTED', isGreen: false);
        }
      });
    }
  }

  Future<void> _initializePreview() async {
    if (!_isVisionPlatform) {
      setState(() {
        _isUnsupported = true;
        _isLoading = false;
      });
      return;
    }

    try {
      final int textureId = await widget.visionManager.startPreview();
      if (!mounted) {
        await widget.visionManager.stopPreview();
        return;
      }

      setState(() {
        _textureId = textureId;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Failed to initialize vision preview: $e';
        _isLoading = false;
      });
    }
  }

  Future<Map<dynamic, dynamic>> shoot() {
    return widget.visionManager.shoot();
  }

  Future<Map<dynamic, dynamic>> registerPlayer({
    required String playerId,
    required List<Uint8List> imageBytes,
  }) {
    return widget.visionManager.registerPlayer(
      playerId: playerId,
      imageBytes: imageBytes,
    );
  }

  Future<String> exportEmbeddings({required String playerId}) {
    return widget.visionManager.exportEmbeddings(playerId: playerId);
  }

  Future<String> exportAll() {
    return widget.visionManager.exportAll();
  }

  Future<void> importEmbeddings({required String json}) {
    return widget.visionManager.importEmbeddings(json: json);
  }

  Future<void> clearRegistrations() {
    return widget.visionManager.clearRegistrations();
  }

  void showGameNotification(String message, {required bool isGreen}) {
    final GameNotification notification = GameNotification(
      id: _nextNotificationId++,
      message: message,
      isGreen: isGreen,
      createdAt: DateTime.now(),
    );

    setState(() {
      _notifications.add(notification);
      if (_notifications.length > 2) {
        _notifications.removeAt(0);
      }
    });

    Timer(const Duration(seconds: 3), () {
      if (!mounted) {
        return;
      }

      setState(() {
        _notifications.removeWhere((GameNotification n) => n.id == notification.id);
      });
    });
  }

  @override
  void dispose() {
    if (_isVisionPlatform && _textureId != null) {
      unawaited(widget.visionManager.stopPreview());
    }
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
                  'Quit Game?',
                  style: TextStyle(
                    color: CyberColors.textPrimary,
                    fontSize: 24 / 1.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Are you sure you want to quit the game?',
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

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop) {
          return;
        }

        final bool shouldQuit = await _confirmExit();
        if (shouldQuit && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_isUnsupported) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Vision module is currently supported on Android only.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final int? textureId = _textureId;
    if (textureId == null) {
      return const Center(child: Text('Vision preview is not ready.'));
    }

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Texture(textureId: textureId),
        IgnorePointer(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[Color(0x44000000), Color(0x55000000)],
              ),
            ),
          ),
        ),
        const IgnorePointer(child: _ScanlineOverlay()),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const _TopHudBar(),
                const Spacer(),
                const Spacer(),
                _NotificationStack(notifications: _notifications),
              ],
            ),
          ),
        ),
        const IgnorePointer(child: _CrosshairOverlay()),
      ],
    );
  }
}

class GameNotification {
  const GameNotification({
    required this.id,
    required this.message,
    required this.isGreen,
    required this.createdAt,
  });

  final int id;
  final String message;
  final bool isGreen;
  final DateTime createdAt;
}

class _TopHudBar extends StatelessWidget {
  const _TopHudBar();

  @override
  Widget build(BuildContext context) {
    return const Align(
      alignment: Alignment.topCenter,
      child: _IntegrityBlock(),
    );
  }
}

class _IntegrityBlock extends StatelessWidget {
  const _IntegrityBlock();

  @override
  Widget build(BuildContext context) {
    const int hpPercent = 60;
    const int totalBars = 10;
    final int activeBars = ((hpPercent / 100) * totalBars).round();

    return Container(
      width: 480,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: CyberColors.panelSoft.withValues(alpha: 0.85),
        border: Border.all(color: CyberColors.line.withValues(alpha: 0.25)),
      ),
      child: Row(
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
                (int i) => Expanded(
                  child: Container(
                    height: 11,
                    margin: EdgeInsets.only(right: i == totalBars - 1 ? 0 : 4),
                    decoration: BoxDecoration(
                      color: i < activeBars
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
          const Text(
            '$hpPercent%',
            style: TextStyle(
              color: CyberColors.lime,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationStack extends StatelessWidget {
  const _NotificationStack({required this.notifications});

  final List<GameNotification> notifications;
  static const double _healthBarWidth = 480;
  static const double _notificationScale = 0.7;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: _healthBarWidth * _notificationScale,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: notifications
              .map((GameNotification notification) => _NotificationCard(notification: notification))
              .toList(growable: false),
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.notification});

  final GameNotification notification;
  static const double _notificationScale = 0.7;

  @override
  Widget build(BuildContext context) {
    final Color accent = notification.isGreen ? CyberColors.lime : const Color(0xFFFF4C52);

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
          fontSize: 16 * _notificationScale,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.7,
        ),
      ),
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
