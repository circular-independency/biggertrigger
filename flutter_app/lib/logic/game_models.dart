/// Current websocket lifecycle state for the app session.
enum SessionConnectionState {
  disconnected,
  connecting,
  connected,
  error,
}

/// High-level multiplayer match phase reported by the server.
enum MatchPhase {
  lobby,
  inGame,
  finished,
}

/// Visual tone used for transient HUD notifications.
enum NotificationTone {
  info,
  success,
  warning,
  danger,
}

/// Immutable player snapshot received from the authoritative websocket server.
class SessionPlayer {
  const SessionPlayer({
    required this.id,
    required this.hp,
    required this.alive,
    required this.ready,
    required this.registered,
    required this.isHost,
  });

  factory SessionPlayer.fromJson(
    Map<String, dynamic> json, {
    required bool isHost,
  }) {
    return SessionPlayer(
      id: json['id'] as String? ?? '',
      hp: (json['hp'] as num?)?.toInt() ?? 0,
      alive: json['alive'] as bool? ?? false,
      ready: json['ready'] as bool? ?? false,
      registered: json['registered'] as bool? ?? false,
      isHost: isHost,
    );
  }

  final String id;
  final int hp;
  final bool alive;
  final bool ready;
  final bool registered;
  final bool isHost;
}

/// One short-lived UI notification rendered on the game HUD.
class SessionNotification {
  const SessionNotification({
    required this.id,
    required this.message,
    required this.tone,
  });

  final int id;
  final String message;
  final NotificationTone tone;
}
