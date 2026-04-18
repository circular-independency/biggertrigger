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
Flutter owns camera preview and capture.
The native plugin no longer starts/stops camera or returns a texture id.

## Endpoints

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

### `shootFrame`

Request:

```dart
final Map<dynamic, dynamic> result = await _channel.invokeMethod('shootFrame', {
  'width': image.width,
  'height': image.height,
  'rotationDegrees': rotationDegrees,
  'planes': image.planes.map((plane) => {
    'bytes': plane.bytes,
    'bytesPerRow': plane.bytesPerRow,
    'bytesPerPixel': plane.bytesPerPixel,
  }).toList(),
});
```

Arguments:

- `width: int`
- `height: int`
- `rotationDegrees: int`
- `planes: List<Map>`
  - `bytes: Uint8List`
  - `bytesPerRow: int`
  - `bytesPerPixel: int?`

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
- `shootFrame` expects Android `YUV_420_888` planes from the Flutter camera stream
- the plugin evaluates all detected people in the frame and performs identity matching

## Expected Flutter-side data types

- `imageBytes`: `List<Uint8List>`
- JSON import/export payloads: `String`
- shoot frame payload: `Map`
- shoot result: `Map`

## Assumptions

- Flutter owns camera preview and feeds frame payloads to the plugin on shoot.
- Registrations are stored only in memory unless Flutter exports and persists the JSON itself.

## Suggested usage order

1. Start Flutter camera preview in your game screen
2. Register the local player from several JPEGs
3. Exchange exported embeddings with other players
4. Import received embeddings
5. On each shot, pass the latest camera frame to `shootFrame`
