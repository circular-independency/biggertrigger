import 'game_models.dart';

enum LobbyPlayerStatusType {
  host,
  ready,
  registered,
  waiting,
  eliminated,
  placeholder,
}

class LobbyPlayer {
  const LobbyPlayer({
    required this.name,
    required this.status,
    required this.statusType,
    this.isPlaceholder = false,
  });

  final String name;
  final String status;
  final LobbyPlayerStatusType statusType;
  final bool isPlaceholder;

  factory LobbyPlayer.fromSessionPlayer(
    SessionPlayer player, {
    required bool isLocalPlayer,
  }) {
    final String displayName = isLocalPlayer ? '${player.id} // YOU' : player.id;

    if (!player.alive) {
      return LobbyPlayer(
        name: displayName,
        status: 'ELIMINATED',
        statusType: LobbyPlayerStatusType.eliminated,
      );
    }

    if (player.isHost) {
      return LobbyPlayer(
        name: displayName,
        status: player.ready ? 'HOST // READY' : 'HOST',
        statusType: LobbyPlayerStatusType.host,
      );
    }

    if (player.ready) {
      return LobbyPlayer(
        name: displayName,
        status: 'READY',
        statusType: LobbyPlayerStatusType.ready,
      );
    }

    if (player.registered) {
      return LobbyPlayer(
        name: displayName,
        status: 'REGISTERED',
        statusType: LobbyPlayerStatusType.registered,
      );
    }

    return LobbyPlayer(
      name: displayName,
      status: 'WAITING',
      statusType: LobbyPlayerStatusType.waiting,
    );
  }

  static LobbyPlayer placeholder(int index) {
    return LobbyPlayer(
      name: 'EMPTY_SLOT_${index + 1}',
      status: 'SCANNING...',
      statusType: LobbyPlayerStatusType.placeholder,
      isPlaceholder: true,
    );
  }
}
