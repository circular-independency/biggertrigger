import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../components/cyber_theme.dart';
import '../components/hud_background.dart';

/// Captures a small set of JPEG registration images for the local player.
class RegistrationPage extends StatefulWidget {
  const RegistrationPage({super.key});

  static const int requiredShots = 3;

  @override
  State<RegistrationPage> createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage> {
  CameraController? _cameraController;
  final List<Uint8List> _captures = <Uint8List>[];
  bool _isInitializing = true;
  bool _isCapturing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_initializeCamera());
  }

  Future<void> _initializeCamera() async {
    try {
      final List<CameraDescription> cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _error = 'No camera available on this device.';
          _isInitializing = false;
        });
        return;
      }

      final CameraDescription selectedCamera = cameras.firstWhere(
        (CameraDescription camera) =>
            camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final CameraController controller = CameraController(
        selectedCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _cameraController = controller;
        _isInitializing = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Failed to initialize registration camera: $error';
        _isInitializing = false;
      });
    }
  }

  Future<void> _captureFrame() async {
    final CameraController? controller = _cameraController;
    if (controller == null ||
        !controller.value.isInitialized ||
        _isCapturing ||
        _captures.length >= RegistrationPage.requiredShots) {
      return;
    }

    setState(() {
      _isCapturing = true;
    });

    try {
      final XFile file = await controller.takePicture();
      final Uint8List bytes = await file.readAsBytes();

      if (!mounted) {
        return;
      }

      setState(() {
        _captures.add(bytes);
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF9B1C25),
            content: Text('Failed to capture image: $error'),
          ),
        );
    } finally {
      if (mounted) {
        setState(() {
          _isCapturing = false;
        });
      }
    }
  }

  void _removeLastCapture() {
    if (_captures.isEmpty) {
      return;
    }

    setState(() {
      _captures.removeLast();
    });
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: HudBackground(
        child: SafeArea(
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isInitializing) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: CyberColors.textPrimary),
          ),
        ),
      );
    }

    final CameraController? controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) {
      return const Center(
        child: Text(
          'Registration camera is not ready.',
          style: TextStyle(color: CyberColors.textPrimary),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                color: CyberColors.cyan,
                icon: const Icon(Icons.arrow_back),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'PLAYER REGISTRATION',
                  style: TextStyle(
                    color: CyberColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Have another player frame your body with the back camera and capture 3 clear shots.',
            style: TextStyle(
              color: CyberColors.textMuted,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  CameraPreview(controller),
                  IgnorePointer(
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: <Color>[Color(0x22000000), Color(0x55000000)],
                        ),
                      ),
                    ),
                  ),
                  const IgnorePointer(child: _RegistrationGuide()),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: List<Widget>.generate(RegistrationPage.requiredShots, (int index) {
              final bool captured = index < _captures.length;
              return Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: captured
                      ? CyberColors.lime.withValues(alpha: 0.18)
                      : CyberColors.panelSoft,
                  border: Border.all(
                    color: captured ? CyberColors.lime : CyberColors.cyan.withValues(alpha: 0.35),
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  captured ? 'OK' : '${index + 1}',
                  style: TextStyle(
                    color: captured ? CyberColors.lime : CyberColors.textMuted,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  onPressed: _captures.isNotEmpty ? _removeLastCapture : null,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: CyberColors.amber,
                    side: BorderSide(color: CyberColors.amber.withValues(alpha: 0.65)),
                  ),
                  child: const Text('UNDO'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: _captures.length >= RegistrationPage.requiredShots
                      ? () {
                          Navigator.of(context).pop<List<Uint8List>>(_captures);
                        }
                      : (_isCapturing ? null : _captureFrame),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _captures.length >= RegistrationPage.requiredShots
                        ? CyberColors.lime
                        : CyberColors.cyan,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                    ),
                  ),
                  child: Text(
                    _captures.length >= RegistrationPage.requiredShots
                        ? 'SYNC PLAYER'
                        : _isCapturing
                        ? 'CAPTURING...'
                        : 'CAPTURE',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RegistrationGuide extends StatelessWidget {
  const _RegistrationGuide();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 160,
        height: 260,
        decoration: BoxDecoration(
          border: Border.all(
            color: CyberColors.cyan.withValues(alpha: 0.85),
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
