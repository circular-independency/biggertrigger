import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import 'cyber_panel.dart';
import 'cyber_theme.dart';
import '../logic/sound_manager.dart';

enum LobbyRegistrationOverlayStage {
  prompt,
  permissionDenied,
  permissionPermanentlyDenied,
  countdown,
  capturing,
  processing,
  failure,
}

class LobbyRegistrationOverlay extends StatelessWidget {
  const LobbyRegistrationOverlay({
    super.key,
    required this.stage,
    required this.capturedCount,
    required this.totalShots,
    required this.onCancel,
    required this.onConfirmStart,
    required this.onRetryPermission,
    required this.onOpenSettings,
    required this.onRetryAfterFailure,
    this.cameraController,
    this.countdownValue,
    this.errorMessage,
  });

  final LobbyRegistrationOverlayStage stage;
  final CameraController? cameraController;
  final int capturedCount;
  final int totalShots;
  final int? countdownValue;
  final String? errorMessage;
  final VoidCallback onCancel;
  final VoidCallback onConfirmStart;
  final VoidCallback onRetryPermission;
  final VoidCallback onOpenSettings;
  final VoidCallback onRetryAfterFailure;

  bool get _canPreview =>
      cameraController != null && cameraController!.value.isInitialized;

  @override
  Widget build(BuildContext context) {
    final String progressLabel = 'SHOT ${capturedCount.clamp(0, totalShots)} / $totalShots';

    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.82),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820, maxHeight: 620),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: CyberPanel(
                  glow: true,
                  borderRadius: 0,
                  borderColor: CyberColors.cyan.withValues(alpha: 0.6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      const Text(
                        '[PLAYER_REGISTRATION]',
                        style: TextStyle(
                          color: CyberColors.amber,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'READY UP FACE SCAN',
                        style: TextStyle(
                          color: CyberColors.textPrimary,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        progressLabel,
                        style: const TextStyle(
                          color: CyberColors.cyan,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: ClipRect(
                          child: Container(
                            color: const Color(0xFF030711),
                            alignment: Alignment.center,
                            child: _canPreview
                                ? CameraPreview(cameraController!)
                                : const _PreviewPlaceholder(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildStateMessage(),
                      const SizedBox(height: 12),
                      _buildActions(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStateMessage() {
    switch (stage) {
      case LobbyRegistrationOverlayStage.prompt:
        return const Text(
          'We will capture 8 photos of you for player embedding. Press OK to start. A 3-second countdown runs before every shot.',
          style: TextStyle(
            color: CyberColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        );
      case LobbyRegistrationOverlayStage.permissionDenied:
        return const Text(
          'Camera permission is required to capture your registration photos.',
          style: TextStyle(
            color: CyberColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        );
      case LobbyRegistrationOverlayStage.permissionPermanentlyDenied:
        return const Text(
          'Camera permission is permanently denied. Open settings and allow camera access.',
          style: TextStyle(
            color: CyberColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        );
      case LobbyRegistrationOverlayStage.countdown:
        return Text(
          'Get ready. Capturing next photo in ${countdownValue ?? 3}...',
          style: const TextStyle(
            color: CyberColors.cyan,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
          textAlign: TextAlign.center,
        );
      case LobbyRegistrationOverlayStage.capturing:
        return const Text(
          'Capturing image...',
          style: TextStyle(
            color: CyberColors.cyan,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
          textAlign: TextAlign.center,
        );
      case LobbyRegistrationOverlayStage.processing:
        return Row(
          children: const <Widget>[
            SizedBox(
              height: 16,
              width: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: CyberColors.lime,
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Embedding player profile...',
                style: TextStyle(
                  color: CyberColors.lime,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        );
      case LobbyRegistrationOverlayStage.failure:
        return Text(
          errorMessage ?? 'Registration failed. Please try again.',
          style: const TextStyle(
            color: Color(0xFFFF6C75),
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        );
    }
  }

  Widget _buildActions() {
    switch (stage) {
      case LobbyRegistrationOverlayStage.prompt:
        return Row(
          children: <Widget>[
            Expanded(child: _button('CANCEL', onCancel, outlined: true)),
            const SizedBox(width: 10),
            Expanded(child: _button('OK', onConfirmStart, accent: CyberColors.lime)),
          ],
        );
      case LobbyRegistrationOverlayStage.permissionDenied:
        return Row(
          children: <Widget>[
            Expanded(child: _button('CANCEL', onCancel, outlined: true)),
            const SizedBox(width: 10),
            Expanded(child: _button('REQUEST AGAIN', onRetryPermission, accent: CyberColors.lime)),
          ],
        );
      case LobbyRegistrationOverlayStage.permissionPermanentlyDenied:
        return Row(
          children: <Widget>[
            Expanded(child: _button('CANCEL', onCancel, outlined: true)),
            const SizedBox(width: 10),
            Expanded(child: _button('OPEN SETTINGS', onOpenSettings, accent: CyberColors.lime)),
          ],
        );
      case LobbyRegistrationOverlayStage.failure:
        return Row(
          children: <Widget>[
            Expanded(child: _button('CANCEL', onCancel, outlined: true)),
            const SizedBox(width: 10),
            Expanded(
              child: _button('TRY AGAIN', onRetryAfterFailure, accent: CyberColors.lime),
            ),
          ],
        );
      case LobbyRegistrationOverlayStage.countdown:
      case LobbyRegistrationOverlayStage.capturing:
      case LobbyRegistrationOverlayStage.processing:
        return Row(
          children: <Widget>[
            Expanded(child: _button('ABORT', onCancel, outlined: true)),
          ],
        );
    }
  }

  Widget _button(
    String label,
    VoidCallback onTap, {
    bool outlined = false,
    Color? accent,
  }) {
    if (outlined) {
      return OutlinedButton(
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: CyberColors.cyan.withValues(alpha: 0.75)),
          foregroundColor: CyberColors.cyan,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        ),
        onPressed: () {
          unawaited(SoundManager.playButton());
          onTap();
        },
        child: Text(label),
      );
    }

    final Color color = accent ?? CyberColors.cyan;
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.black,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      ),
      onPressed: () {
        unawaited(SoundManager.playButton());
        onTap();
      },
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _PreviewPlaceholder extends StatelessWidget {
  const _PreviewPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: const <Widget>[
        Icon(Icons.videocam_outlined, color: CyberColors.textMuted, size: 36),
        SizedBox(height: 8),
        Text(
          'Camera preview is preparing...',
          style: TextStyle(
            color: CyberColors.textMuted,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
