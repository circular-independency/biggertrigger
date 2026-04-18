import 'dart:typed_data';

import 'package:flutter/services.dart';

/// Method-channel wrapper around the native Android vision module.
class VisionBridge {
  VisionBridge({MethodChannel? channel})
    : _channel =
          channel ?? const MethodChannel('com.yourteam.visionmodule/vision');

  final MethodChannel _channel;

  Future<int> startPreview() async {
    final int? textureId = await _channel.invokeMethod<int>('startPreview');
    if (textureId == null) {
      throw StateError('Vision plugin returned no texture id.');
    }
    return textureId;
  }

  Future<void> stopPreview() async {
    await _channel.invokeMethod<void>('stopPreview');
  }

  Future<int> registerPlayer(String playerId, List<Uint8List> imageBytes) async {
    final Map<Object?, Object?>? result =
        await _channel.invokeMethod<Map<Object?, Object?>>('registerPlayer', <String, Object?>{
          'playerId': playerId,
          'imageBytes': imageBytes,
        });

    if (result == null) {
      throw StateError('Vision plugin returned no registration response.');
    }

    final Object? storedCount = result['storedCount'];
    if (storedCount is! int) {
      throw StateError('Vision plugin returned an invalid storedCount value.');
    }

    return storedCount;
  }

  Future<String> exportEmbeddings(String playerId) async {
    final String? json = await _channel.invokeMethod<String>(
      'exportEmbeddings',
      <String, Object?>{'playerId': playerId},
    );
    if (json == null) {
      throw StateError('Vision plugin returned no embeddings payload.');
    }
    return json;
  }

  Future<String> exportAll() async {
    final String? json = await _channel.invokeMethod<String>('exportAll');
    if (json == null) {
      throw StateError('Vision plugin returned no registry payload.');
    }
    return json;
  }

  Future<void> importEmbeddings(String json) async {
    await _channel.invokeMethod<void>(
      'importEmbeddings',
      <String, Object?>{'json': json},
    );
  }

  Future<void> clearRegistrations() async {
    await _channel.invokeMethod<void>('clearRegistrations');
  }

  Future<VisionShootResult> shoot() async {
    final Map<Object?, Object?>? result =
        await _channel.invokeMethod<Map<Object?, Object?>>('shoot');

    if (result == null) {
      throw StateError('Vision plugin returned no shoot result.');
    }

    final String type = (result['result'] as String?) ?? 'UNKNOWN';
    switch (type) {
      case 'MISS':
        return const VisionShootResult.miss();
      case 'UNKNOWN':
        return const VisionShootResult.unknown();
      case 'HIT':
        final String targetId = (result['targetId'] as String?) ?? '';
        final num confidenceValue = (result['confidence'] as num?) ?? 0;
        if (targetId.isEmpty) {
          throw StateError('Vision plugin returned HIT without targetId.');
        }
        return VisionShootResult.hit(
          targetId: targetId,
          confidence: confidenceValue.toDouble(),
        );
      default:
        throw StateError('Unsupported shoot result type: $type');
    }
  }
}

enum VisionShootResultType {
  miss,
  unknown,
  hit,
}

/// Flutter-side representation of one native `shoot()` call result.
class VisionShootResult {
  const VisionShootResult._({
    required this.type,
    this.targetId,
    this.confidence,
  });

  const VisionShootResult.miss() : this._(type: VisionShootResultType.miss);

  const VisionShootResult.unknown()
    : this._(type: VisionShootResultType.unknown);

  const VisionShootResult.hit({
    required String targetId,
    required double confidence,
  }) : this._(
         type: VisionShootResultType.hit,
         targetId: targetId,
         confidence: confidence,
       );

  final VisionShootResultType type;
  final String? targetId;
  final double? confidence;
}
