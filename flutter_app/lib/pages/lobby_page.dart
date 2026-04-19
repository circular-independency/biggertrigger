import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../components/hud_background.dart';
import '../components/hud_header.dart';
import '../components/lobby_action_bar.dart';
import '../components/lobby_mission_card.dart';
import '../components/lobby_operatives_panel.dart';
import '../components/lobby_registration_overlay.dart';
import '../logic/lobby_manager.dart';
import '../logic/socket_manager.dart';
import '../logic/user_preferences_manager.dart';
import '../logic/vision_manager.dart';
import '../main.dart';
import 'game_page.dart';

class LobbyPage extends StatefulWidget {
  LobbyPage({
    super.key,
    LobbyManager? lobbyManager,
    SocketManager? socketManager,
    VisionManager? visionManager,
  }) : lobbyManager = lobbyManager ?? LobbyManager(),
       socketManager = socketManager ?? SocketManager(),
       visionManager = visionManager ?? const VisionManager();

  final LobbyManager lobbyManager;
  final SocketManager socketManager;
  final VisionManager visionManager;

  @override
  State<LobbyPage> createState() => _LobbyPageState();
}

class _LobbyPageState extends State<LobbyPage> {
  static const int _totalRegistrationShots = 2;

  bool _isConnecting = true;
  bool _didNavigateAway = false;
  bool _didNavigateToGame = false;

  StreamSubscription<Map<String, SocketLobbyUser>>? _usersSubscription;
  StreamSubscription<String>? _messagesSubscription;
  StreamSubscription<SocketStartPayload>? _startSubscription;
  Map<String, SocketLobbyUser> _latestUsers = <String, SocketLobbyUser>{};
  String _currentUsername = 'COMMANDER_01';

  LobbyRegistrationOverlayStage? _registrationStage;
  CameraController? _registrationCameraController;
  bool _isPreparingRegistrationCamera = false;
  bool _isDisposingRegistrationCamera = false;
  int _registrationCountdown = 3;
  int _capturedShots = 0;
  String? _registrationError;
  int _registrationSessionToken = 0;
  final List<Uint8List> _registrationImages = <Uint8List>[];

  bool get _isRegistrationVisible => _registrationStage != null;

  @override
  void initState() {
    super.initState();
    unawaited(_loadCurrentUsername());
    widget.lobbyManager.attachSocketManager(widget.socketManager);
    _usersSubscription = widget.socketManager.usersUpdates.listen(
      (Map<String, SocketLobbyUser> users) {
        if (!mounted) {
          return;
        }
        setState(() {
          _latestUsers = users;
          widget.lobbyManager.updatePlayersFromSocket(users);
        });
      },
    );
    _startSubscription = widget.socketManager.startUpdates.listen(
      _handleStartPayload,
      onError: (Object error) {
        _goToHomeWithError(error);
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

  Future<void> _loadCurrentUsername() async {
    final String stored = (await UserPreferencesManager.getUsername())?.trim() ?? '';
    if (!mounted) {
      return;
    }
    setState(() {
      _currentUsername = stored.isEmpty ? 'COMMANDER_01' : stored;
    });
  }

  bool _isLocalUserReady() {
    if (widget.lobbyManager.getCurrentStatus() == LobbyStatus.active) {
      return true;
    }

    final SocketLobbyUser? localUser = _latestUsers[_currentUsername];
    return localUser?.ready ?? false;
  }

  void _handleStartPayload(SocketStartPayload payload) {
    if (!mounted || _didNavigateAway || _didNavigateToGame) {
      return;
    }

    if (!_isLocalUserReady()) {
      return;
    }

    _didNavigateToGame = true;
    _cancelRegistrationFlow();
    Navigator.pushNamed(
      context,
      DragonHackApp.gameRoute,
      arguments: GameStartData(
        embeddingsByPlayer: payload.embeddingsByUser,
        healthByPlayer: payload.healthByUser,
        currentUsername: _currentUsername,
        socketManager: widget.socketManager,
      ),
    ).whenComplete(() {
      if (mounted) {
        _didNavigateToGame = false;
      }
    });
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
    _cancelRegistrationFlow();
    Navigator.pushNamedAndRemoveUntil(
      context,
      DragonHackApp.mainMenuRoute,
      (Route<dynamic> route) => false,
      arguments: 'Socket connection failed: $error',
    );
  }

  Future<void> _openRegistrationOverlay() async {
    if (!mounted || _didNavigateAway || _isRegistrationVisible) {
      return;
    }

    setState(() {
      _registrationStage = LobbyRegistrationOverlayStage.prompt;
      _registrationError = null;
      _capturedShots = 0;
      _registrationCountdown = 3;
      _registrationImages.clear();
    });

    await _prepareRegistrationCamera(requestIfNeeded: true);
  }

  Future<void> _prepareRegistrationCamera({required bool requestIfNeeded}) async {
    if (!mounted || !_isRegistrationVisible || _isPreparingRegistrationCamera) {
      return;
    }

    final CameraController? existing = _registrationCameraController;
    if (existing != null && existing.value.isInitialized) {
      return;
    }

    _isPreparingRegistrationCamera = true;
    try {
      PermissionStatus status = await Permission.camera.status;
      if (!status.isGranted && requestIfNeeded) {
        status = await Permission.camera.request();
      }

      if (!mounted || !_isRegistrationVisible) {
        return;
      }

      if (status.isPermanentlyDenied) {
        setState(() {
          _registrationStage =
              LobbyRegistrationOverlayStage.permissionPermanentlyDenied;
        });
        return;
      }

      if (!status.isGranted) {
        setState(() {
          _registrationStage = LobbyRegistrationOverlayStage.permissionDenied;
        });
        return;
      }

      final List<CameraDescription> cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _registrationStage = LobbyRegistrationOverlayStage.failure;
          _registrationError = 'No camera is available on this device.';
        });
        return;
      }

      final CameraDescription selectedCamera = cameras.firstWhere(
        (CameraDescription camera) =>
            camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      final CameraController controller = CameraController(
        selectedCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await controller.initialize();

      if (!mounted || !_isRegistrationVisible) {
        await controller.dispose();
        return;
      }

      final CameraController? previousController = _registrationCameraController;
      _registrationCameraController = controller;
      if (previousController != null) {
        await previousController.dispose();
      }

      setState(() {
        if (_registrationStage == LobbyRegistrationOverlayStage.permissionDenied ||
            _registrationStage ==
                LobbyRegistrationOverlayStage.permissionPermanentlyDenied ||
            _registrationStage == LobbyRegistrationOverlayStage.failure) {
          _registrationStage = LobbyRegistrationOverlayStage.prompt;
          _registrationError = null;
        }
      });
    } catch (error) {
      if (!mounted || !_isRegistrationVisible) {
        return;
      }
      setState(() {
        _registrationStage = LobbyRegistrationOverlayStage.failure;
        _registrationError = 'Failed to initialize registration camera: $error';
      });
    } finally {
      _isPreparingRegistrationCamera = false;
    }
  }

  Future<void> _startRegistrationSequence() async {
    if (!mounted || !_isRegistrationVisible) {
      return;
    }

    if (_registrationStage != LobbyRegistrationOverlayStage.prompt &&
        _registrationStage != LobbyRegistrationOverlayStage.failure) {
      return;
    }

    if (_registrationCameraController == null ||
        !(_registrationCameraController?.value.isInitialized ?? false)) {
      await _prepareRegistrationCamera(requestIfNeeded: true);
    }

    final CameraController? controller = _registrationCameraController;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    final int token = ++_registrationSessionToken;
    _registrationImages.clear();

    if (mounted) {
      setState(() {
        _capturedShots = 0;
        _registrationError = null;
      });
    }

    for (int shotIndex = 0; shotIndex < _totalRegistrationShots; shotIndex += 1) {
      for (int countdown = 3; countdown >= 1; countdown -= 1) {
        if (!_isActiveRegistrationSession(token)) {
          return;
        }
        setState(() {
          _registrationStage = LobbyRegistrationOverlayStage.countdown;
          _registrationCountdown = countdown;
          _capturedShots = shotIndex;
        });
        await Future<void>.delayed(const Duration(seconds: 1));
      }

      if (!_isActiveRegistrationSession(token)) {
        return;
      }

      setState(() {
        _registrationStage = LobbyRegistrationOverlayStage.capturing;
      });

      try {
        final XFile shot = await controller.takePicture();
        final Uint8List bytes = await shot.readAsBytes();
        unawaited(SystemSound.play(SystemSoundType.click));
        if (!_isActiveRegistrationSession(token)) {
          return;
        }
        _registrationImages.add(bytes);
        setState(() {
          _capturedShots = shotIndex + 1;
        });
      } catch (error) {
        if (!_isActiveRegistrationSession(token)) {
          return;
        }
        setState(() {
          _registrationStage = LobbyRegistrationOverlayStage.failure;
          _registrationError = 'Capture failed on shot ${shotIndex + 1}: $error';
        });
        return;
      }
    }

    if (!_isActiveRegistrationSession(token)) {
      return;
    }

    setState(() {
      _registrationStage = LobbyRegistrationOverlayStage.processing;
    });

    final String storedUsername = (await UserPreferencesManager.getUsername())?.trim() ?? '';
    final String playerId = storedUsername.isEmpty ? 'COMMANDER_01' : storedUsername;

    try {
      final Map<dynamic, dynamic> registration = await widget.visionManager.registerPlayer(
        playerId: playerId,
        imageBytes: List<Uint8List>.unmodifiable(_registrationImages),
      );

      final dynamic playerEmbedding = registration['playerEmbedding'];
      if (playerEmbedding is! Map) {
        throw StateError('Missing playerEmbedding in register response.');
      }

      final dynamic rawEmbeddings = playerEmbedding['embeddings'];
      if (rawEmbeddings is! List) {
        throw StateError('Missing embeddings list in register response.');
      }

      await widget.socketManager.sendEmbedding(embeddings: rawEmbeddings);
    } catch (error) {
      if (!_isActiveRegistrationSession(token)) {
        return;
      }
      setState(() {
        _registrationStage = LobbyRegistrationOverlayStage.failure;
        _registrationError = 'Embedding failed: $error';
      });
      return;
    }

    if (!_isActiveRegistrationSession(token)) {
      return;
    }

    setState(() {
      widget.lobbyManager.setReady(notifySocket: false);
      _registrationStage = null;
      _registrationError = null;
      _registrationCountdown = 3;
      _capturedShots = 0;
      _registrationImages.clear();
    });

    await _disposeRegistrationCamera();
  }

  bool _isActiveRegistrationSession(int token) {
    return mounted &&
        !_didNavigateAway &&
        _isRegistrationVisible &&
        token == _registrationSessionToken;
  }

  void _cancelRegistrationFlow() {
    _registrationSessionToken += 1;
    if (mounted) {
      setState(() {
        _registrationStage = null;
        _registrationError = null;
        _registrationCountdown = 3;
        _capturedShots = 0;
        _registrationImages.clear();
      });
    }
    unawaited(_disposeRegistrationCamera());
  }

  Future<void> _disposeRegistrationCamera() async {
    if (_isDisposingRegistrationCamera) {
      return;
    }

    _isDisposingRegistrationCamera = true;
    try {
      final CameraController? controller = _registrationCameraController;
      _registrationCameraController = null;
      if (controller != null) {
        await controller.dispose();
      }
    } catch (_) {
      // Best-effort cleanup.
    } finally {
      _isDisposingRegistrationCamera = false;
    }
  }

  Future<void> _openCameraSettings() async {
    await openAppSettings();
  }

  @override
  void dispose() {
    _registrationSessionToken += 1;
    _startSubscription?.cancel();
    _messagesSubscription?.cancel();
    _usersSubscription?.cancel();
    widget.socketManager.disconnect();
    unawaited(_disposeRegistrationCamera());
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
          child: Stack(
            children: <Widget>[
              Positioned.fill(
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    final double pad = constraints.maxWidth * 0.05;
                    final double gap = constraints.maxHeight * 0.014;

                    return Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: pad, vertical: gap),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          HudHeader(
                            onSettingsTap: () {
                              Navigator.pushNamed(
                                context,
                                DragonHackApp.settingsRoute,
                              );
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
                              activeCount:
                                  widget.lobbyManager.activeOperativesCount,
                              totalSlots:
                                  widget.lobbyManager.totalOperativeSlots,
                            ),
                          ),
                          SizedBox(height: gap * 1.2),
                          LobbyActionBar(
                            isReady: isReady,
                            startEnabled: false,
                            onReadyTap: () {
                              unawaited(_openRegistrationOverlay());
                            },
                            onStartTap: () {},
                          ),
                          SizedBox(height: gap * 0.4),
                        ],
                      ),
                    );
                  },
                ),
              ),
              if (_isRegistrationVisible)
                LobbyRegistrationOverlay(
                  stage: _registrationStage!,
                  cameraController: _registrationCameraController,
                  capturedCount: _capturedShots,
                  totalShots: _totalRegistrationShots,
                  countdownValue: _registrationCountdown,
                  errorMessage: _registrationError,
                  onCancel: _cancelRegistrationFlow,
                  onConfirmStart: () {
                    unawaited(_startRegistrationSequence());
                  },
                  onRetryPermission: () {
                    unawaited(_prepareRegistrationCamera(requestIfNeeded: true));
                  },
                  onOpenSettings: () {
                    unawaited(_openCameraSettings());
                  },
                  onRetryAfterFailure: () {
                    unawaited(_startRegistrationSequence());
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
