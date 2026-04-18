import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'game_models.dart';
import 'socket_manager.dart';
import 'user_preferences_manager.dart';
import 'vision_bridge.dart';

/// Single source of truth for the Flutter app session.
///
/// Responsibilities:
/// - connect/disconnect websocket transport
/// - mirror authoritative server state
/// - synchronize embeddings through the native vision plugin
/// - manage preview lifecycle and `shoot()` calls
/// - expose simple state for lobby and game pages
class GameSessionController extends ChangeNotifier {
  GameSessionController({
    SocketManager? socketManager,
    VisionBridge? visionBridge,
  }) : _socketManager = socketManager ?? SocketManager(),
       _visionBridge = visionBridge ?? VisionBridge();

  final SocketManager _socketManager;
  final VisionBridge _visionBridge;
  final List<Timer> _notificationTimers = <Timer>[];

  StreamSubscription<Map<String, dynamic>>? _socketSubscription;
  bool _disposed = false;
  int _nextNotificationId = 0;

  SessionConnectionState _connectionState = SessionConnectionState.disconnected;
  MatchPhase _phase = MatchPhase.lobby;
  String _username = '';
  String _serverUrl = SocketManager.defaultSocketUrl();
  String? _hostId;
  String? _winnerId;
  String? _lastError;
  List<SessionPlayer> _players = const <SessionPlayer>[];
  Set<String> _syncedEmbeddingIds = <String>{};
  List<SessionNotification> _notifications = const <SessionNotification>[];

  bool _isRegistering = false;
  bool _isStartingGame = false;
  bool _isShooting = false;
  bool _isPreviewStarting = false;
  int? _previewTextureId;
  int _localEmbeddingCount = 0;
  bool _localRegistrationComplete = false;

  SessionConnectionState get connectionState => _connectionState;
  MatchPhase get phase => _phase;
  String get username => _username;
  String get serverUrl => _serverUrl;
  String? get hostId => _hostId;
  String? get winnerId => _winnerId;
  String? get lastError => _lastError;
  List<SessionPlayer> get players => _players;
  List<SessionNotification> get notifications => _notifications;
  Set<String> get syncedEmbeddingIds => _syncedEmbeddingIds;
  int? get previewTextureId => _previewTextureId;
  int get localEmbeddingCount => _localEmbeddingCount;
  bool get isRegistering => _isRegistering;
  bool get isStartingGame => _isStartingGame;
  bool get isShooting => _isShooting;
  bool get isPreviewStarting => _isPreviewStarting;
  bool get isConnected => _connectionState == SessionConnectionState.connected;
  bool get hasPreview => _previewTextureId != null;
  bool get isLobbyHost => _hostId == _username;
  bool get hasLocalRegistration => _localRegistrationComplete;
  bool get allPlayersReady =>
      _players.isNotEmpty && _players.every((SessionPlayer player) => player.ready);
  bool get allPlayersRegistered =>
      _players.isNotEmpty &&
      _players.every((SessionPlayer player) => player.registered);
  bool get canStartGame =>
      isLobbyHost &&
      _phase == MatchPhase.lobby &&
      _players.length >= 2 &&
      allPlayersReady &&
      allPlayersRegistered &&
      !_isStartingGame;
  bool get canRegister =>
      isConnected &&
      _phase == MatchPhase.lobby &&
      !_isRegistering &&
      !_localRegistrationComplete;
  bool get canShoot =>
      _phase == MatchPhase.inGame &&
      hasPreview &&
      !_isPreviewStarting &&
      !_isShooting &&
      (localPlayer?.alive ?? false);
  String get lobbyCode => 'LAN-8765';

  SessionPlayer? get localPlayer {
    for (final SessionPlayer player in _players) {
      if (player.id == _username) {
        return player;
      }
    }
    return null;
  }

  bool get isLocalEliminated =>
      _phase == MatchPhase.inGame && !(localPlayer?.alive ?? true);

  bool get isLocalWinner => _winnerId != null && _winnerId == _username;

  /// Connects to the configured websocket server and joins the single shared lobby.
  Future<void> connect() async {
    if (_connectionState == SessionConnectionState.connecting || isConnected) {
      return;
    }

    _resetRuntimeState();
    _lastError = null;
    _setConnectionState(SessionConnectionState.connecting);

    final String? savedUsername = await UserPreferencesManager.getUsername();
    final String resolvedUsername = savedUsername?.trim().isNotEmpty == true
        ? savedUsername!.trim()
        : 'COMMANDER_01';
    final String? savedServerUrl = await UserPreferencesManager.getServerUrl();
    final String resolvedServerUrl = SocketManager.normalizeSocketUrl(
      savedServerUrl?.trim().isNotEmpty == true
          ? savedServerUrl!.trim()
          : SocketManager.defaultSocketUrl(),
    );

    _username = resolvedUsername;
    _serverUrl = resolvedServerUrl;
    await _socketSubscription?.cancel();
    _socketSubscription = _socketManager.events.listen(
      _handleSocketEvent,
      onError: _handleSocketError,
    );

    try {
      await _visionBridge.stopPreview();
    } catch (_) {
      // Ignore preview cleanup failures during reconnect.
    }

    try {
      await _visionBridge.clearRegistrations();
      await _socketManager.connect(_serverUrl);
      _socketManager.sendJson(<String, Object?>{
        'type': 'join',
        'username': _username,
      });
      _setConnectionState(SessionConnectionState.connected);
      _pushNotification('LINK ESTABLISHED', tone: NotificationTone.success);
    } catch (error, stackTrace) {
      _handleSocketError(error, stackTrace);
      rethrow;
    }
  }

  /// Disconnects from the current match and clears local transient state.
  Future<void> disconnect() async {
    await _stopPreviewInternal();
    await _visionBridge.clearRegistrations();
    await _socketSubscription?.cancel();
    _socketSubscription = null;
    await _socketManager.disconnect();
    _resetRuntimeState();
    _setConnectionState(SessionConnectionState.disconnected);
  }

  /// Captures registration images locally, stores embeddings natively, uploads them to the server,
  /// and marks the player as ready.
  Future<void> registerAndReady(List<Uint8List> images) async {
    if (!canRegister) {
      return;
    }

    if (images.isEmpty) {
      throw ArgumentError('At least one registration image is required.');
    }

    _isRegistering = true;
    _notifySafely();

    try {
      final int storedCount = await _visionBridge.registerPlayer(_username, images);
      final String exportJson = await _visionBridge.exportEmbeddings(_username);
      final Map<String, dynamic> registry =
          (jsonDecode(exportJson) as Map<Object?, Object?>).cast<String, dynamic>();

      _localEmbeddingCount = storedCount;
      _localRegistrationComplete = true;

      _socketManager.sendJson(<String, Object?>{
        'type': 'sync_embeddings',
        'registry': registry,
      });
      _socketManager.sendJson(<String, Object?>{
        'type': 'set_ready',
        'ready': true,
      });

      _pushNotification(
        'IDENTITY LOCKED // $storedCount EMBEDDINGS',
        tone: NotificationTone.success,
      );
    } finally {
      _isRegistering = false;
      _notifySafely();
    }
  }

  /// Requests the authoritative server to start the match.
  Future<void> startGame() async {
    if (!canStartGame) {
      return;
    }

    _isStartingGame = true;
    _notifySafely();
    try {
      _socketManager.sendJson(<String, Object?>{'type': 'start_game'});
    } finally {
      _isStartingGame = false;
      _notifySafely();
    }
  }

  /// Starts the native CameraX texture preview used during gameplay.
  Future<void> startVisionPreview() async {
    if (_previewTextureId != null || _isPreviewStarting) {
      return;
    }

    _isPreviewStarting = true;
    _notifySafely();

    try {
      _previewTextureId = await _visionBridge.startPreview();
    } finally {
      _isPreviewStarting = false;
      _notifySafely();
    }
  }

  /// Stops the native gameplay preview.
  Future<void> stopVisionPreview() async {
    await _stopPreviewInternal();
    _notifySafely();
  }

  /// Executes a local shoot attempt and forwards confirmed hits to the server.
  Future<void> shoot() async {
    if (!canShoot) {
      return;
    }

    _isShooting = true;
    _notifySafely();

    try {
      final VisionShootResult result = await _visionBridge.shoot();

      switch (result.type) {
        case VisionShootResultType.miss:
          _pushNotification('MISS', tone: NotificationTone.warning);
          break;
        case VisionShootResultType.unknown:
          _pushNotification('UNKNOWN TARGET', tone: NotificationTone.warning);
          break;
        case VisionShootResultType.hit:
          final String targetId = result.targetId!;
          if (targetId == _username) {
            _pushNotification('SELF MATCH BLOCKED', tone: NotificationTone.warning);
            break;
          }

          final double confidence = result.confidence ?? 0;
          _socketManager.sendJson(<String, Object?>{
            'type': 'shoot',
            'targetId': targetId,
            'confidence': confidence,
          });
          _pushNotification(
            'TARGET LOCK // $targetId ${(confidence * 100).toStringAsFixed(0)}%',
            tone: NotificationTone.success,
          );
          break;
      }
    } finally {
      _isShooting = false;
      _notifySafely();
    }
  }

  void _handleSocketEvent(Map<String, dynamic> event) {
    switch (event['type']) {
      case 'state':
        _applyServerState(event);
        return;
      case 'embeddings_sync':
        unawaited(_applyEmbeddingsSync(event['registry']));
        return;
      case 'event':
        _applyServerEvent(event);
        return;
      case 'error':
        _applyServerError(event);
        return;
      case 'socket_closed':
        _lastError ??= 'Socket connection closed.';
        _setConnectionState(SessionConnectionState.disconnected);
        _pushNotification('LINK LOST', tone: NotificationTone.danger);
        return;
      default:
        return;
    }
  }

  void _handleSocketError(Object error, StackTrace stackTrace) {
    _lastError = error.toString();
    _setConnectionState(SessionConnectionState.error);
    _pushNotification('NETWORK ERROR', tone: NotificationTone.danger);
  }

  void _applyServerState(Map<String, dynamic> event) {
    final String? nextHostId = event['hostId'] as String?;
    final String? nextWinnerId = event['winnerId'] as String?;
    final List<dynamic> rawPlayers = event['players'] as List<dynamic>? ?? <dynamic>[];

    _hostId = nextHostId;
    _winnerId = nextWinnerId;
    _phase = _parsePhase(event['phase'] as String?);
    _players = rawPlayers
        .whereType<Map<String, dynamic>>()
        .map(
          (Map<String, dynamic> json) => SessionPlayer.fromJson(
            json,
            isHost: json['id'] == nextHostId,
          ),
        )
        .toList(growable: false);

    _localRegistrationComplete =
        _localRegistrationComplete || (localPlayer?.registered ?? false);
    _notifySafely();
  }

  Future<void> _applyEmbeddingsSync(dynamic registryData) async {
    if (registryData is! Map) {
      return;
    }

    final Map<String, dynamic> registry = registryData.cast<String, dynamic>();
    final String json = jsonEncode(registry);

    await _visionBridge.clearRegistrations();
    if (registry.isNotEmpty) {
      await _visionBridge.importEmbeddings(json);
    }

    _syncedEmbeddingIds = registry.keys.toSet();
    _notifySafely();
  }

  void _applyServerEvent(Map<String, dynamic> event) {
    final String? kind = event['kind'] as String?;
    final String? message = event['message'] as String?;
    if (message == null || message.isEmpty) {
      return;
    }

    switch (kind) {
      case 'player_joined':
      case 'registration_synced':
      case 'game_started':
        _pushNotification(message, tone: NotificationTone.success);
        return;
      case 'player_left':
      case 'player_eliminated':
      case 'game_finished':
        _pushNotification(message, tone: NotificationTone.warning);
        return;
      case 'shot_resolved':
        _pushNotification(message, tone: NotificationTone.info);
        return;
      default:
        _pushNotification(message, tone: NotificationTone.info);
        return;
    }
  }

  void _applyServerError(Map<String, dynamic> event) {
    final String? code = event['code'] as String?;
    _lastError = event['message'] as String? ?? 'Unknown server error.';
    _pushNotification(_lastError!, tone: NotificationTone.danger);

    if (code == 'INVALID_USERNAME' ||
        code == 'USERNAME_TAKEN' ||
        code == 'LOBBY_FULL' ||
        code == 'MATCH_IN_PROGRESS') {
      _setConnectionState(SessionConnectionState.error);
    }
  }

  MatchPhase _parsePhase(String? value) {
    switch (value) {
      case 'in_game':
        return MatchPhase.inGame;
      case 'finished':
        return MatchPhase.finished;
      case 'lobby':
      default:
        return MatchPhase.lobby;
    }
  }

  Future<void> _stopPreviewInternal() async {
    if (_previewTextureId == null && !_isPreviewStarting) {
      return;
    }

    try {
      await _visionBridge.stopPreview();
    } finally {
      _previewTextureId = null;
      _isPreviewStarting = false;
    }
  }

  void _pushNotification(String message, {required NotificationTone tone}) {
    final SessionNotification notification = SessionNotification(
      id: _nextNotificationId++,
      message: message,
      tone: tone,
    );

    _notifications = <SessionNotification>[
      ..._notifications,
      notification,
    ];
    if (_notifications.length > 3) {
      _notifications = _notifications.sublist(_notifications.length - 3);
    }
    _notifySafely();

    final Timer timer = Timer(const Duration(seconds: 3), () {
      _notifications = _notifications
          .where((SessionNotification item) => item.id != notification.id)
          .toList(growable: false);
      _notifySafely();
    });
    _notificationTimers.add(timer);
  }

  void _resetRuntimeState() {
    _phase = MatchPhase.lobby;
    _hostId = null;
    _winnerId = null;
    _players = const <SessionPlayer>[];
    _syncedEmbeddingIds = <String>{};
    _notifications = const <SessionNotification>[];
    _isRegistering = false;
    _isStartingGame = false;
    _isShooting = false;
    _isPreviewStarting = false;
    _previewTextureId = null;
    _localEmbeddingCount = 0;
    _localRegistrationComplete = false;
    for (final Timer timer in _notificationTimers) {
      timer.cancel();
    }
    _notificationTimers.clear();
  }

  void _setConnectionState(SessionConnectionState state) {
    _connectionState = state;
    _notifySafely();
  }

  void _notifySafely() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  Future<void> close() async {
    if (_disposed) {
      return;
    }

    _disposed = true;
    for (final Timer timer in _notificationTimers) {
      timer.cancel();
    }
    _notificationTimers.clear();
    await _stopPreviewInternal();
    await _visionBridge.clearRegistrations();
    await _socketSubscription?.cancel();
    _socketSubscription = null;
    await _socketManager.dispose();
    _resetRuntimeState();
  }

  @override
  void dispose() {
    unawaited(close());
    super.dispose();
  }
}
