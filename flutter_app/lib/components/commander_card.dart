import 'package:flutter/material.dart';

import 'cyber_theme.dart';

class CommanderCard extends StatelessWidget {
  const CommanderCard({
    super.key,
    required this.commanderName,
    required this.levelText,
    required this.rankLabel,
    required this.progressText,
    required this.progress,
  });

  final String commanderName;
  final String levelText;
  final String rankLabel;
  final String progressText;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final int activeSegments = (progress.clamp(0, 1) * 10).round();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CyberColors.panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: CyberColors.line.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                commanderName,
                style: CyberText.section,
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                color: CyberColors.lime,
                child: const Text(
                  'ACTIVE_SESSION',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Expanded(
                child: Text(
                  levelText,
                  style: const TextStyle(
                    color: CyberColors.textPrimary,
                    fontSize: 40 / 1.5,
                    fontWeight: FontWeight.w800,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
              Text(
                rankLabel,
                style: CyberText.tiny,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              progressText,
              style: const TextStyle(
                color: CyberColors.textPrimary,
                fontSize: 18 / 1.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: List<Widget>.generate(
              10,
              (int index) => Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: index == 9 ? 0 : 4),
                  height: 16,
                  decoration: BoxDecoration(
                    color: index < activeSegments
                        ? CyberColors.lime
                        : CyberColors.lime.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: index < activeSegments ? CyberShadows.glow : null,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
