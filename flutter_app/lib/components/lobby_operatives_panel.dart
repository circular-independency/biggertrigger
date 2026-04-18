import 'package:flutter/material.dart';

import '../logic/lobby_manager.dart';
import 'cyber_panel.dart';
import 'cyber_theme.dart';
import 'operative_row.dart';

class LobbyOperativesPanel extends StatelessWidget {
  const LobbyOperativesPanel({
    super.key,
    required this.players,
    required this.activeCount,
    required this.totalSlots,
  });

  final List<LobbyPlayer> players;
  final int activeCount;
  final int totalSlots;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text('[DEPLOYMENT_READY]', style: CyberText.section.copyWith(color: CyberColors.amber)),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            const Expanded(
              child: Text(
                'ACTIVE_OPERATIVES',
                style: TextStyle(
                  color: CyberColors.textPrimary,
                  fontSize: 33 / 1.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              '$activeCount',
              style: const TextStyle(
                color: CyberColors.lime,
                fontSize: 68 / 1.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              '/$totalSlots',
              style: CyberText.value.copyWith(fontSize: 24),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Expanded(
          child: CyberPanel(
            glow: true,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          'OPERATIVE_NAME',
                          style: TextStyle(
                            color: CyberColors.textMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      Text(
                        'SYSTEM_STATUS',
                        style: TextStyle(
                          color: CyberColors.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: players.length,
                    itemBuilder: (BuildContext context, int index) {
                      final LobbyPlayer player = players[index];
                      return OperativeRow(
                        name: player.name,
                        statusText: player.status,
                        statusColor: _statusColor(player.statusType),
                        markerColor: _markerColor(index, player.statusType),
                        placeholder: player.isPlaceholder,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Color _statusColor(LobbyPlayerStatusType type) {
    switch (type) {
      case LobbyPlayerStatusType.ready:
        return CyberColors.lime;
      case LobbyPlayerStatusType.host:
        return CyberColors.cyan;
      case LobbyPlayerStatusType.registered:
        return CyberColors.cyan;
      case LobbyPlayerStatusType.waiting:
        return CyberColors.amber;
      case LobbyPlayerStatusType.eliminated:
        return const Color(0xFFFF4C52);
      case LobbyPlayerStatusType.placeholder:
        return CyberColors.textMuted.withValues(alpha: 0.4);
    }
  }

  Color _markerColor(int index, LobbyPlayerStatusType type) {
    if (type == LobbyPlayerStatusType.placeholder) {
      return Colors.transparent;
    }
    if (type == LobbyPlayerStatusType.ready) {
      return CyberColors.lime;
    }
    if (type == LobbyPlayerStatusType.waiting) {
      return CyberColors.amber;
    }
    if (type == LobbyPlayerStatusType.eliminated) {
      return const Color(0xFFFF4C52);
    }

    return index.isEven ? CyberColors.cyan : CyberColors.cyan.withValues(alpha: 0.7);
  }
}
