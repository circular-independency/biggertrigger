import 'socket_manager.dart';

enum LobbyStatus {
  pending,
  active,
}

enum LobbyPlayerStatusType {
  lockedIn,
  online,
  waiting,
  scanning,
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

  LobbyPlayer copyWith({
    String? name,
    String? status,
    LobbyPlayerStatusType? statusType,
    bool? isPlaceholder,
  }) {
    return LobbyPlayer(
      name: name ?? this.name,
      status: status ?? this.status,
      statusType: statusType ?? this.statusType,
      isPlaceholder: isPlaceholder ?? this.isPlaceholder,
    );
  }
}

class LobbyManager {
  LobbyStatus _status = LobbyStatus.pending;

  final List<LobbyPlayer> _players = <LobbyPlayer>[];

  LobbyStatus getCurrentStatus() => _status;

  bool get canStart => _status == LobbyStatus.active;

  List<LobbyPlayer> getActivePlayers() => List<LobbyPlayer>.unmodifiable(_players);

  int get activeOperativesCount =>
      _players.where((LobbyPlayer p) => !p.isPlaceholder).length;

  int get totalOperativeSlots => 8;

  void updatePlayersFromSocket(Map<String, SocketLobbyUser> users) {
    final List<MapEntry<String, SocketLobbyUser>> sortedEntries =
        users.entries.toList()..sort((a, b) => a.key.compareTo(b.key));

    _players
      ..clear()
      ..addAll(
        sortedEntries.map((MapEntry<String, SocketLobbyUser> entry) {
          final SocketLobbyUser user = entry.value;
          if (!user.alive) {
            return LobbyPlayer(
              name: entry.key,
              status: 'DOWN',
              statusType: LobbyPlayerStatusType.waiting,
            );
          }

          if (user.ready) {
            return LobbyPlayer(
              name: entry.key,
              status: 'LOCKED IN',
              statusType: LobbyPlayerStatusType.lockedIn,
            );
          }

          return LobbyPlayer(
            name: entry.key,
            status: 'WAITING',
            statusType: LobbyPlayerStatusType.online,
          );
        }),
      );

    while (_players.length < totalOperativeSlots) {
      _players.add(
        const LobbyPlayer(
          name: 'EMPTY_SLOT',
          status: 'SCANNING...',
          statusType: LobbyPlayerStatusType.scanning,
          isPlaceholder: true,
        ),
      );
    }
  }

  void setReady() {
    _status = LobbyStatus.active;

    if (_players.isNotEmpty) {
      _players[0] = _players[0].copyWith(
        status: 'LOCKED IN',
        statusType: LobbyPlayerStatusType.lockedIn,
      );
    }
  }

  String statusLabel(LobbyStatus status) {
    switch (status) {
      case LobbyStatus.pending:
        return 'Pending';
      case LobbyStatus.active:
        return 'Active';
    }
  }
}
