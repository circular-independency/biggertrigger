import 'package:flutter/services.dart';

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

  Future<int> startPreview() async {
    try {
      final int? textureId = await _channel.invokeMethod<int>('startPreview');
      if (textureId == null) {
        throw VisionException('startPreview returned no texture id.');
      }
      return textureId;
    } on PlatformException catch (e) {
      throw VisionException(
        e.message ?? 'Failed to start vision preview (${e.code}).',
      );
    }
  }

  Future<void> stopPreview() async {
    try {
      await _channel.invokeMethod<void>('stopPreview');
    } on PlatformException catch (e) {
      throw VisionException(
        e.message ?? 'Failed to stop vision preview (${e.code}).',
      );
    }
  }

  Future<Map<dynamic, dynamic>> shoot() async {
    try {
      final Map<dynamic, dynamic>? result =
          await _channel.invokeMethod<Map<dynamic, dynamic>>('shoot');
      return result ?? <dynamic, dynamic>{};
    } on PlatformException catch (e) {
      throw VisionException(e.message ?? 'Shoot failed (${e.code}).');
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
