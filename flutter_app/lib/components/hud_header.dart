import 'package:flutter/material.dart';

import 'cyber_theme.dart';

class HudHeader extends StatelessWidget {
  const HudHeader({
    super.key,
    required this.onSettingsTap,
    this.systemName = 'KINETIC_OS // V2.4',
    this.signal = '[SIG_STR: 98%]',
    this.signalLabel,
    this.signalValue,
    this.avatarIcon = Icons.shield_moon_outlined,
  });

  final VoidCallback onSettingsTap;
  final String systemName;
  final String signal;
  final String? signalLabel;
  final String? signalValue;
  final IconData avatarIcon;

  @override
  Widget build(BuildContext context) {
    final bool useSplitSignal = signalLabel != null && signalValue != null;

    return Row(
      children: <Widget>[
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: const LinearGradient(
              colors: <Color>[Color(0xFF213349), Color(0xFF0E1B2D)],
            ),
            border: Border.all(color: CyberColors.cyan.withValues(alpha: 0.3)),
          ),
          child: Icon(avatarIcon, color: CyberColors.cyan),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                systemName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: CyberColors.cyan,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 2),
              if (useSplitSignal)
                RichText(
                  text: TextSpan(
                    children: <InlineSpan>[
                      TextSpan(
                        text: signalLabel,
                        style: const TextStyle(
                          color: CyberColors.cyan,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const TextSpan(text: '  '),
                      TextSpan(
                        text: signalValue,
                        style: const TextStyle(
                          color: CyberColors.lime,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Text(
                  signal,
                  style: const TextStyle(
                    color: CyberColors.amber,
                    fontSize: 24 / 1.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
            ],
          ),
        ),
        IconButton(
          onPressed: onSettingsTap,
          iconSize: 30,
          color: CyberColors.cyan,
          icon: const Icon(Icons.settings_suggest_rounded),
        ),
      ],
    );
  }
}
