enum LobbyStatus {
  pending,
  ready,
}

class LobbyManager {
  const LobbyManager();

  LobbyStatus getCurrentStatus() {
    return LobbyStatus.pending;
  }

  String statusLabel(LobbyStatus status) {
    switch (status) {
      case LobbyStatus.pending:
        return 'Pending';
      case LobbyStatus.ready:
        return 'Ready';
    }
  }
}
