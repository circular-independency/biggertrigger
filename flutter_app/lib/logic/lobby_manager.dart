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

  final List<LobbyPlayer> _players = <LobbyPlayer>[
    const LobbyPlayer(
      name: 'COMMANDER_01',
      status: 'WAITING',
      statusType: LobbyPlayerStatusType.waiting,
    ),
    const LobbyPlayer(
      name: 'GHOST_STALKER',
      status: 'ONLINE',
      statusType: LobbyPlayerStatusType.online,
    ),
    const LobbyPlayer(
      name: 'NEON_VIPER',
      status: 'WAITING',
      statusType: LobbyPlayerStatusType.waiting,
    ),
    const LobbyPlayer(
      name: 'CYBER_PUNK_88',
      status: 'ONLINE',
      statusType: LobbyPlayerStatusType.online,
    ),
    const LobbyPlayer(
      name: 'EMPTY_SLOT',
      status: 'SCANNING...',
      statusType: LobbyPlayerStatusType.scanning,
      isPlaceholder: true,
    ),
  ];

  LobbyStatus getCurrentStatus() => _status;

  bool get canStart => _status == LobbyStatus.active;

  List<LobbyPlayer> getActivePlayers() => List<LobbyPlayer>.unmodifiable(_players);

  int get activeOperativesCount =>
      _players.where((LobbyPlayer p) => !p.isPlaceholder).length;

  int get totalOperativeSlots => 8;

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
