import 'package:flutter/material.dart';

import '../logic/lobby_manager.dart';

class LobbyPage extends StatelessWidget {
  const LobbyPage({super.key, this.lobbyManager = const LobbyManager()});

  final LobbyManager lobbyManager;

  @override
  Widget build(BuildContext context) {
    final LobbyStatus status = lobbyManager.getCurrentStatus();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lobby'),
      ),
      body: Center(
        child: Card(
          margin: const EdgeInsets.all(24),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Your Status',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                Text(
                  lobbyManager.statusLabel(status),
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
