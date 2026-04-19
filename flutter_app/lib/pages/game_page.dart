import 'dart:async';
import 'dart:convert';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../components/cyber_theme.dart';
import '../main.dart';
import '../logic/sound_manager.dart';
import '../logic/socket_manager.dart';
import '../logic/vision_manager.dart';

enum GameCameraPermissionState {
  unknown,
  requesting,
  denied,
  permanentlyDenied,
  granted,
}

class GameStartData {
  const GameStartData({
    required this.embeddingsByPlayer,
    required this.healthByPlayer,
    required this.currentUsername,
    this.socketManager,
  });

  final Map<String, List<List<double>>> embeddingsByPlayer;
  final Map<String, int> healthByPlayer;
  final String currentUsername;
  final SocketManager? socketManager;
}

class GamePage extends StatefulWidget {
  const GamePage({
    super.key,
    VisionManager? visionManager,
    this.startData,
  }) : visionManager = visionManager ?? const VisionManager();

  final VisionManager visionManager;
  final GameStartData? startData;

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> with WidgetsBindingObserver {
  static const Duration _shootCooldown = Duration(milliseconds: 350);

  CameraController? _cameraController;
  VisionFrame? _latestFrame;
  String? _error;
  bool _isLoading = true;
  bool _isUnsupported = false;
  bool _isStartingCamera = false;
  bool _isShootInFlight = false;
  bool _hasShownInitialNotifications = false;
  GameCameraPermissionState _permissionState = GameCameraPermissionState.unknown;
  DateTime _nextAllowedShootAt = DateTime.fromMillisecondsSinceEpoch(0);

  final List<GameNotification> _notifications = <GameNotification>[];
  int _nextNotificationId = 0;
  Map<String, List<List<double>>> _playerEmbeddingsByName =
      <String, List<List<double>>>{};
  List<String> _playerIds = <String>[];
  SocketManager? _socketManager;
  String _currentUsername = 'COMMANDER_01';
  int _currentHp = 100;
  bool _didHandleDeath = false;
  bool _isRegistrySyncing = false;
  String? _registrySyncError;
  StreamSubscription<Map<String, SocketLobbyUser>>? _usersSubscription;
  bool _showDamageFlash = false;
  Timer? _damageFlashTimer;

  bool get _isVisionPlatform =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    _applyStartData(widget.startData);
    unawaited(_syncVisionRegistryFromStartData());
    _attachSocketListeners();
    unawaited(SoundManager.playDeny());
    WidgetsBinding.instance.addObserver(this);
    unawaited(_configureGameScreen());
  }

  void _applyStartData(GameStartData? startData) {
    if (startData == null) {
      return;
    }

    final Map<String, List<List<double>>> copied =
        <String, List<List<double>>>{};
    startData.embeddingsByPlayer.forEach((String key, List<List<double>> value) {
      copied[key] = value
          .map((List<double> embedding) => List<double>.from(embedding))
          .toList(growable: false);
    });

    _playerEmbeddingsByName = copied;
    _playerIds = copied.keys.toList(growable: false)..sort();
    _socketManager = startData.socketManager;
    _currentUsername = startData.currentUsername.trim().isEmpty
        ? 'COMMANDER_01'
        : startData.currentUsername.trim();
    _currentHp = (startData.healthByPlayer[_currentUsername] ?? 100).clamp(0, 100);
  }

  Future<void> _syncVisionRegistryFromStartData() async {
    if (_isRegistrySyncing || _playerEmbeddingsByName.isEmpty) {
      return;
    }

    _isRegistrySyncing = true;
    _registrySyncError = null;
    try {
      // Do not keep local player's vectors in the runtime match registry,
      // otherwise self-recognition dominates and every hit resolves to self.
      final Map<String, List<List<double>>> remotePlayers =
          <String, List<List<double>>>{};
      _playerEmbeddingsByName.forEach((String playerId, List<List<double>> vectors) {
        if (playerId == _currentUsername) {
          return;
        }
        if (vectors.isNotEmpty) {
          remotePlayers[playerId] = vectors;
        }
      });

      await widget.visionManager.clearRegistrations();
      if (remotePlayers.isNotEmpty) {
        await widget.visionManager.importEmbeddings(
          json: jsonEncode(remotePlayers),
        );
      }
    } catch (error) {
      _registrySyncError = error.toString();
      if (mounted) {
        showGameNotification('EMBEDDING SYNC FAILED', isGreen: false);
      }
    } finally {
      _isRegistrySyncing = false;
    }
  }

  void _attachSocketListeners() {
    final SocketManager? socketManager = _socketManager;
    if (socketManager == null) {
      return;
    }

    _usersSubscription = socketManager.usersUpdates.listen(
      _handleUsersUpdate,
    );
  }

  void _handleUsersUpdate(Map<String, SocketLobbyUser> users) {
    final SocketLobbyUser? me = users[_currentUsername];
    if (!mounted || me == null) {
      return;
    }

    final int previousHp = _currentHp;
    final int nextHp = me.hp.clamp(0, 100);
    if (_currentHp != nextHp) {
      setState(() {
        _currentHp = nextHp;
      });
    }
    if (nextHp < previousHp) {
      unawaited(SoundManager.playHurt());
      _triggerDamageFlash();
    }

    if (!me.alive || nextHp <= 0) {
      _handleDeath();
    }
  }

  void _triggerDamageFlash() {
    _damageFlashTimer?.cancel();
    if (!mounted) {
      return;
    }

    setState(() {
      _showDamageFlash = true;
    });

    _damageFlashTimer = Timer(const Duration(milliseconds: 170), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _showDamageFlash = false;
      });
    });
  }

  void _handleDeath() {
    if (!mounted || _didHandleDeath) {
      return;
    }
    _didHandleDeath = true;

    Navigator.pushReplacementNamed(
      context,
      DragonHackApp.endGameRoute,
      arguments: <String, dynamic>{
        'username': _currentUsername,
      },
    );
  }

  Future<void> _sendHitToServer(String targetUser) async {
    final SocketManager? socketManager = _socketManager;
    if (socketManager == null || !socketManager.isConnected) {
      return;
    }

    try {
      socketManager.sendShoot(targetUser: targetUser);
    } catch (_) {
      if (!mounted) {
        return;
      }
      showGameNotification('HIT SYNC FAILED', isGreen: false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _isVisionPlatform &&
        _cameraController == null) {
      unawaited(_ensurePermissionAndMaybeStartPreview(requestIfNeeded: false));
    }
  }

  Future<void> _configureGameScreen() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    await _ensurePermissionAndMaybeStartPreview(requestIfNeeded: true);
  }

  Future<void> _ensurePermissionAndMaybeStartPreview({
    required bool requestIfNeeded,
  }) async {
    if (!_isVisionPlatform) {
      setState(() {
        _isUnsupported = true;
        _isLoading = false;
      });
      return;
    }

    final bool hasPermission = await _ensureCameraPermission(
      requestIfNeeded: requestIfNeeded,
    );
    if (!mounted) {
      return;
    }

    if (!hasPermission) {
      setState(() {
        _isLoading = false;
        _error = null;
      });
      return;
    }

    await _initializePreview();
    _showInitialNotificationsIfNeeded();
  }

  Future<bool> _ensureCameraPermission({required bool requestIfNeeded}) async {
    PermissionStatus status = await Permission.camera.status;
    if (status.isGranted) {
      _setPermissionState(GameCameraPermissionState.granted);
      return true;
    }

    if (requestIfNeeded && (status.isDenied || status.isRestricted || status.isLimited)) {
      _setPermissionState(GameCameraPermissionState.requesting);
      status = await Permission.camera.request();
    }

    if (status.isGranted) {
      _setPermissionState(GameCameraPermissionState.granted);
      return true;
    }

    if (status.isPermanentlyDenied) {
      _setPermissionState(GameCameraPermissionState.permanentlyDenied);
      return false;
    }

    _setPermissionState(GameCameraPermissionState.denied);
    return false;
  }

  void _setPermissionState(GameCameraPermissionState newState) {
    if (!mounted || _permissionState == newState) {
      return;
    }
    setState(() {
      _permissionState = newState;
    });
  }

  void _showInitialNotificationsIfNeeded() {
    if (!mounted ||
        _hasShownInitialNotifications ||
        _isUnsupported ||
        _cameraController == null) {
      return;
    }

    _hasShownInitialNotifications = true;
    showGameNotification('SECURE_LINK_ESTABLISHED', isGreen: true);
    if (_playerIds.isNotEmpty) {
      final Iterable<MapEntry<String, List<List<double>>>> remotePlayers =
          _playerEmbeddingsByName.entries.where(
            (MapEntry<String, List<List<double>>> e) =>
                e.key != _currentUsername,
          );
      final int totalVectors = remotePlayers.fold<int>(
        0,
        (int sum, MapEntry<String, List<List<double>>> e) =>
            sum + e.value.length,
      );
      final int remotePlayerCount = remotePlayers.length;
      Future<void>.delayed(const Duration(milliseconds: 450), () {
        if (mounted) {
          showGameNotification(
            _registrySyncError == null
                ? 'TARGET DB: $remotePlayerCount OPS / $totalVectors VECTORS'
                : 'TARGET DB SYNC ISSUE',
            isGreen: true,
          );
        }
      });
    }
    Future<void>.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        showGameNotification('LOW_SIGNAL_ZONE_DETECTED', isGreen: false);
      }
    });
  }

  Future<void> _requestCameraPermissionAgain() async {
    await _ensurePermissionAndMaybeStartPreview(requestIfNeeded: true);
  }

  Future<void> _openPermissionSettings() async {
    await openAppSettings();
  }

  Future<void> _initializePreview() async {
    if (!_isVisionPlatform) {
      setState(() {
        _isUnsupported = true;
        _isLoading = false;
      });
      return;
    }

    if (_cameraController != null || _isStartingCamera) {
      return;
    }

    _isStartingCamera = true;
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final List<CameraDescription> cameras = await availableCameras();
      final CameraDescription camera = cameras.firstWhere(
        (CameraDescription c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final CameraController controller = CameraController(
        camera,
        // Higher preset gives less noisy/weird preview on many devices while
        // still keeping frame-stream processing reasonable.
        ResolutionPreset.high,
        enableAudio: false,
        // Keep YUV for native frame pipeline.
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      await controller.initialize();
      await controller.startImageStream(_onCameraImage);

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _cameraController = controller;
        _isLoading = false;
        _permissionState = GameCameraPermissionState.granted;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      final String message = e.toString().toLowerCase();
      if (message.contains('permission')) {
        final PermissionStatus status = await Permission.camera.status;
        if (!mounted) {
          return;
        }

        setState(() {
          _permissionState = status.isPermanentlyDenied
              ? GameCameraPermissionState.permanentlyDenied
              : GameCameraPermissionState.denied;
          _error = null;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to initialize vision preview: $e';
          _isLoading = false;
        });
      }
    } finally {
      _isStartingCamera = false;
    }
  }

  Future<Map<dynamic, dynamic>> shoot() {
    final VisionFrame? frame = _latestFrame;
    if (frame == null) {
      return Future<Map<dynamic, dynamic>>.value(<dynamic, dynamic>{
        'result': 'MISS',
      });
    }
    return widget.visionManager.shootFrame(frame: frame);
  }

  Future<void> _handleShootTap() async {
    if (_currentHp <= 0) {
      return;
    }
    if (_isRegistrySyncing) {
      showGameNotification('SYNCING TARGET DB', isGreen: false);
      return;
    }

    final DateTime now = DateTime.now();
    if (now.isBefore(_nextAllowedShootAt) || _isShootInFlight) {
      return;
    }

    _nextAllowedShootAt = now.add(_shootCooldown);
    _isShootInFlight = true;
    unawaited(SoundManager.playLaser());
    try {
      final Map<dynamic, dynamic> result = await shoot();
      final String type = result['result']?.toString() ?? 'MISS';
      switch (type) {
        case 'HIT':
          final String target = result['targetId']?.toString() ?? 'TARGET';
          unawaited(_sendHitToServer(target));
          showGameNotification('HIT: $target', isGreen: true);
          break;
        case 'UNKNOWN':
          showGameNotification('TARGET UNKNOWN', isGreen: false);
          break;
        case 'MISS':
        default:
          showGameNotification('MISS', isGreen: false);
          break;
      }
    } catch (_) {
      showGameNotification('SHOOT FAILED', isGreen: false);
    } finally {
      _isShootInFlight = false;
    }
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
    WidgetsBinding.instance.removeObserver(this);
    _usersSubscription?.cancel();
    _damageFlashTimer?.cancel();
    final CameraController? controller = _cameraController;
    _cameraController = null;
    _latestFrame = null;
    if (_isVisionPlatform && controller != null) {
      unawaited(controller.dispose());
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
                          unawaited(SoundManager.playButton());
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
                          unawaited(SoundManager.playButton());
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

  Future<void> _quitToHome() async {
    final SocketManager? socketManager = _socketManager;
    if (socketManager != null && socketManager.isConnected) {
      try {
        await socketManager.disconnect();
      } catch (_) {
        // Best-effort disconnect before returning home.
      }
    }

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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop) {
          return;
        }

        final bool shouldQuit = await _confirmExit();
        if (shouldQuit && context.mounted) {
          await _quitToHome();
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

    final CameraController? controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) {
      if (_permissionState == GameCameraPermissionState.denied ||
          _permissionState == GameCameraPermissionState.permanentlyDenied ||
          _permissionState == GameCameraPermissionState.requesting) {
        return _buildPermissionRecoveryPanel();
      }
      return const Center(child: Text('Vision preview is not ready.'));
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        unawaited(_handleShootTap());
      },
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          CameraPreview(controller),
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
          IgnorePointer(
            child: AnimatedOpacity(
              opacity: _showDamageFlash ? 1 : 0,
              duration: const Duration(milliseconds: 80),
              child: Container(
                color: const Color(0x55FF1A1A),
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
                  _TopHudBar(hpPercent: _currentHp),
                  const Spacer(),
                  const Spacer(),
                  _NotificationStack(notifications: _notifications),
                ],
              ),
            ),
          ),
          const IgnorePointer(child: _CrosshairOverlay()),
        ],
      ),
    );
  }

  void _onCameraImage(CameraImage image) {
    final CameraController? controller = _cameraController;
    if (controller == null || image.planes.isEmpty) {
      return;
    }

    if (image.format.group != ImageFormatGroup.yuv420 || image.planes.length < 3) {
      return;
    }

    final List<VisionFramePlane> planes = image.planes.map((Plane plane) {
      return VisionFramePlane(
        bytes: Uint8List.fromList(plane.bytes),
        bytesPerRow: plane.bytesPerRow,
        bytesPerPixel: plane.bytesPerPixel,
      );
    }).toList(growable: false);

    _latestFrame = VisionFrame(
      width: image.width,
      height: image.height,
      // No camera rotation compensation from Flutter side.
      rotationDegrees: 0,
      planes: planes,
    );
  }

  Widget _buildPermissionRecoveryPanel() {
    final bool permanentlyDenied =
        _permissionState == GameCameraPermissionState.permanentlyDenied;
    final bool requesting = _permissionState == GameCameraPermissionState.requesting;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: CyberColors.panel,
              border: Border.all(
                color: CyberColors.cyan.withValues(alpha: 0.45),
                width: 1.2,
              ),
              boxShadow: const <BoxShadow>[
                BoxShadow(color: Color(0x662DDAFF), blurRadius: 18),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  '[CAMERA_ACCESS_REQUIRED]',
                  style: TextStyle(
                    color: CyberColors.amber,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Camera Permission Needed',
                  style: TextStyle(
                    color: CyberColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  permanentlyDenied
                      ? 'Camera permission was permanently denied. Open app settings and allow camera access to continue.'
                      : 'Camera access is required to start the vision preview.',
                  style: const TextStyle(
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
                          side: BorderSide(
                            color: CyberColors.cyan.withValues(alpha: 0.65),
                          ),
                          foregroundColor: CyberColors.cyan,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.zero,
                          ),
                        ),
                        onPressed: requesting
                            ? null
                            : () {
                                unawaited(SoundManager.playButton());
                                unawaited(_requestCameraPermissionAgain());
                              },
                        child: Text(requesting ? 'REQUESTING...' : 'REQUEST AGAIN'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: CyberColors.lime,
                          foregroundColor: Colors.black,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.zero,
                          ),
                        ),
                        onPressed: () {
                          unawaited(SoundManager.playButton());
                          unawaited(_openPermissionSettings());
                        },
                        child: const Text(
                          'OPEN SETTINGS',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
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
  const _TopHudBar({required this.hpPercent});

  final int hpPercent;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: _IntegrityBlock(hpPercent: hpPercent),
    );
  }
}

class _IntegrityBlock extends StatelessWidget {
  const _IntegrityBlock({required this.hpPercent});

  final int hpPercent;

  @override
  Widget build(BuildContext context) {
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
          Text(
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
