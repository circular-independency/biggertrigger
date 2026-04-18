# Flutter Vision Module Integration

This file is for the Flutter developer integrating the native Android vision module.

## Channel

Use this method channel on the Flutter side:

```dart
const _channel = MethodChannel('com.yourteam.visionmodule/vision');
```

## Android registration

`VisionFlutterPlugin` implements `FlutterPlugin`, but this repository is not a packaged Flutter plugin module. That means the Flutter host app should register it explicitly on Android.

In the Flutter Android host, add the plugin in `configureFlutterEngine`:

```kotlin
override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    VisionFlutterPlugin.registerWith(flutterEngine)
}
```

Equivalent direct form:

```kotlin
flutterEngine.plugins.add(VisionFlutterPlugin())
```

If the host already uses generated plugin registration, keep that and add `VisionFlutterPlugin` as an extra plugin.

## Preview flow

Start preview:

```dart
final int textureId = await _channel.invokeMethod('startPreview');
```

Render it:

```dart
Texture(textureId: textureId)
```

Recommended:

- keep the preview centered
- keep the crosshair centered over the same widget
- avoid clipping the texture and crosshair independently
- prefer wrapping the `Texture` in an `AspectRatio` that matches the preview you want to present to the player

Stop preview:

```dart
await _channel.invokeMethod('stopPreview');
```

## Endpoints

### `startPreview`

Request:

- no arguments

Response:

- `int` texture id

Behavior:

- creates a Flutter texture
- binds CameraX preview + analysis to that texture
- starts updating the native shoot pipeline frame holder
- uses the shared native analysis settings from `VisionConfig`:
  preferred `640 x 480`, `KEEP_ONLY_LATEST`, RGBA output, single background analyzer thread

### `stopPreview`

Request:

- no arguments

Response:

- `null`

Behavior:

- unbinds CameraX
- releases the texture

### `registerPlayer`

Request:

```dart
await _channel.invokeMethod('registerPlayer', {
  'playerId': 'alice',
  'imageBytes': <Uint8List>[jpeg1, jpeg2, jpeg3],
});
```

Arguments:

- `playerId: String`
- `imageBytes: List<Uint8List>`
  Each item must be a JPEG-encoded image.

Response:

```dart
{
  'storedCount': 3,
}
```

Errors:

- `REGISTRATION_FAILED`

### `exportEmbeddings`

Request:

```dart
final String json = await _channel.invokeMethod(
  'exportEmbeddings',
  {'playerId': 'alice'},
);
```

Arguments:

- `playerId: String`

Response:

- `String` JSON blob for that player

Example shape:

```json
{"alice":[[0.1,0.2,0.3],[0.4,0.5,0.6]]}
```

### `exportAll`

Request:

```dart
final String json = await _channel.invokeMethod('exportAll');
```

Response:

- `String` full registry JSON

Example shape:

```json
{"alice":[[...],[...]],"bob":[[...]]}
```

### `importEmbeddings`

Request:

```dart
await _channel.invokeMethod('importEmbeddings', {
  'json': receivedJson,
});
```

Arguments:

- `json: String`

Response:

- `null`

Behavior:

- merges imported embeddings into the existing in-memory registry

### `shoot`

Request:

```dart
final Map<dynamic, dynamic> result = await _channel.invokeMethod('shoot');
```

Response variants:

Miss:

```dart
{'result': 'MISS'}
```

Unknown:

```dart
{'result': 'UNKNOWN'}
```

Hit:

```dart
{
  'result': 'HIT',
  'targetId': 'alice',
  'confidence': 0.83,
}
```

Errors:

- `SHOOT_FAILED`

### `clearRegistrations`

Request:

```dart
await _channel.invokeMethod('clearRegistrations');
```

Response:

- `null`

Behavior:

- clears all registered/imported embeddings from native memory

## Notes for the Flutter developer

- `imageBytes` must be JPEG-encoded `Uint8List` values
- registrations live only in native memory until you export and persist/share the returned JSON
- `shoot` depends on the latest analyzed frame, so call `startPreview` before attempting `shoot`
- the native side assumes the gameplay crosshair is visually centered over the preview widget

## Expected Flutter-side data types

- `textureId`: `int`
- `imageBytes`: `List<Uint8List>`
- JSON import/export payloads: `String`
- shoot result: `Map`

## Assumptions

- Flutter draws the crosshair centered over the `Texture` widget.
- The native plugin currently uses the preview texture plus a native analysis frame holder for shoot logic.
- Registrations are stored only in memory unless Flutter exports and persists the JSON itself.

## Suggested usage order

1. Call `startPreview`
2. Render the returned `Texture`
3. Register the local player from several JPEGs
4. Exchange exported embeddings with other players
5. Import received embeddings
6. Call `shoot` whenever the player fires
7. Call `stopPreview` when leaving the vision screen
