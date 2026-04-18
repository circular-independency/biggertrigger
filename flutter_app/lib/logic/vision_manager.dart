import 'package:flutter/services.dart';

class VisionFramePlane {
  const VisionFramePlane({
    required this.bytes,
    required this.bytesPerRow,
    required this.bytesPerPixel,
  });

  final Uint8List bytes;
  final int bytesPerRow;
  final int? bytesPerPixel;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'bytes': bytes,
      'bytesPerRow': bytesPerRow,
      'bytesPerPixel': bytesPerPixel,
    };
  }
}

class VisionFrame {
  const VisionFrame({
    required this.width,
    required this.height,
    required this.rotationDegrees,
    required this.planes,
  });

  final int width;
  final int height;
  final int rotationDegrees;
  final List<VisionFramePlane> planes;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'width': width,
      'height': height,
      'rotationDegrees': rotationDegrees,
      'planes': planes.map((VisionFramePlane plane) => plane.toMap()).toList(),
    };
  }
}

class VisionException implements Exception {
  VisionException(this.message);

  final String message;

  @override
  String toString() => 'VisionException: $message';
}

class VisionManager {
  const VisionManager();

  static const MethodChannel _channel =
      MethodChannel('com.yourteam.visionmodule/vision');

  Future<Map<dynamic, dynamic>> shootFrame({required VisionFrame frame}) async {
    try {
      final Map<dynamic, dynamic>? result =
          await _channel.invokeMethod<Map<dynamic, dynamic>>(
            'shootFrame',
            frame.toMap(),
          );
      return result ?? <dynamic, dynamic>{};
    } on PlatformException catch (e) {
      throw VisionException(
        e.message ?? 'Shoot frame failed (${e.code}).',
      );
    }
  }

  Future<Map<dynamic, dynamic>> registerPlayer({
    required String playerId,
    required List<Uint8List> imageBytes,
  }) async {
    try {
      final Map<dynamic, dynamic>? result =
          await _channel.invokeMethod<Map<dynamic, dynamic>>(
            'registerPlayer',
            <String, dynamic>{
              'playerId': playerId,
              'imageBytes': imageBytes,
            },
          );
      return result ?? <dynamic, dynamic>{};
    } on PlatformException catch (e) {
      throw VisionException(
        e.message ?? 'Player registration failed (${e.code}).',
      );
    }
  }

  Future<String> exportEmbeddings({required String playerId}) async {
    try {
      final String? json = await _channel.invokeMethod<String>(
        'exportEmbeddings',
        <String, dynamic>{'playerId': playerId},
      );
      return json ?? '{}';
    } on PlatformException catch (e) {
      throw VisionException(
        e.message ?? 'Export embeddings failed (${e.code}).',
      );
    }
  }

  Future<String> exportAll() async {
    try {
      final String? json = await _channel.invokeMethod<String>('exportAll');
      return json ?? '{}';
    } on PlatformException catch (e) {
      throw VisionException(
        e.message ?? 'Export all failed (${e.code}).',
      );
    }
  }

  Future<void> importEmbeddings({required String json}) async {
    try {
      await _channel.invokeMethod<void>(
        'importEmbeddings',
        <String, dynamic>{'json': json},
      );
    } on PlatformException catch (e) {
      throw VisionException(
        e.message ?? 'Import embeddings failed (${e.code}).',
      );
    }
  }

  Future<void> clearRegistrations() async {
    try {
      await _channel.invokeMethod<void>('clearRegistrations');
    } on PlatformException catch (e) {
      throw VisionException(
        e.message ?? 'Clear registrations failed (${e.code}).',
      );
    }
  }
}
