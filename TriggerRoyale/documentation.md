# TriggerRoyale Android Vision Notes

This repository now contains two native entry points for the same Kotlin vision stack:

- a temporary Android test harness in `MainActivity`
- a Flutter-facing plugin in `VisionFlutterPlugin`

The shared vision flow is:

- get the latest frame
- detect `person` boxes
- keep the target under the centered crosshair
- crop the selected body
- optionally reject blurry crops
- embed the crop
- match against registered players

## Current structure

- `app/src/main/java/com/example/triggerroyale/MainActivity.kt`
  Native test harness used to validate the vision loop without Flutter.
- `app/src/main/java/com/example/triggerroyale/VisionFlutterPlugin.kt`
  Flutter plugin entrypoint that exposes texture preview, registration, import/export, and `shoot()` through a method channel.
- `app/src/main/java/com/example/triggerroyale/AppLifecycleOwner.kt`
  Minimal always-resumed lifecycle owner used when the plugin is initialized from an application context instead of an `Activity`.
- `app/src/main/java/com/example/triggerroyale/CrosshairOverlayView.kt`
  Draws the native test harness crosshair overlay.
- `app/src/main/java/com/example/triggerroyale/DetectionOverlayView.kt`
  Draws debug rectangles and shoot state in the native test harness.
- `app/src/main/java/com/example/triggerroyale/ObjectDetectorHelper.kt`
  Wraps MediaPipe Object Detector setup and image-mode inference.
- `app/src/main/java/com/example/triggerroyale/ImageEmbedderHelper.kt`
  Wraps MediaPipe Image Embedder setup and one-shot embedding inference.
- `app/src/main/java/com/example/triggerroyale/PlayerEmbedding.kt`
  Data model describing one player's collected embeddings.
- `app/src/main/java/com/example/triggerroyale/PlayerRegistry.kt`
  In-memory registration store with registration, import/export, and read/clear helpers.
- `app/src/main/java/com/example/triggerroyale/FrameHolder.kt`
  Thread-safe holder for the latest frame passed into the shoot pipeline.
- `app/src/main/java/com/example/triggerroyale/EmbeddingMatcher.kt`
  Compares a query embedding against the stored player registry using cosine similarity.
- `app/src/main/java/com/example/triggerroyale/ShootResult.kt`
  Sealed result type for `Miss`, `Unknown`, and `Hit(playerId, confidence)`.
- `app/src/main/java/com/example/triggerroyale/ShootPipeline.kt`
  End-to-end shoot flow: frame -> detect -> crosshair filter -> crop -> blur check -> embed -> match.
- `app/src/main/java/com/example/triggerroyale/CoordinateMapper.kt`
  Utility for mapping between image-space and preview-space rectangles.
- `app/src/main/java/com/example/triggerroyale/CropHelper.kt`
  Extracts person crops and rejects blurry crops using Laplacian variance.
- `app/src/main/java/com/example/triggerroyale/VisionConfig.kt`
  Central place for tunable analysis, detector, embedder, match, and blur settings.
- `app/src/main/res/layout/activity_main.xml`
  Native test harness layout for preview, debug overlay, crosshair, and `SHOOT`.
- `app/build.gradle.kts`
  Android and dependency configuration, including CameraX, MediaPipe Tasks, and Flutter embedding compile-time support.
- `flutter_integration.md`
  Exact Flutter integration guide for the developer wiring the plugin into the Flutter app.

## Camera pipeline

The repository currently uses two camera flows.

### Native test harness (`MainActivity`)

- binds only `Preview`
- renders into `PreviewView`
- reads `PreviewView.bitmap` on demand when `SHOOT` is pressed

Why this path exists:

- it keeps detection, hit-testing, cropping, and the visible preview in one coordinate space
- it avoids continuous `ImageProxy` to `Bitmap` conversion on every frame
- it avoids noisy gralloc errors seen on some Mali devices in the continuous conversion path

### Flutter plugin (`VisionFlutterPlugin`)

- binds `Preview` and `ImageAnalysis`
- renders `Preview` into a Flutter texture
- keeps the latest upright analysis bitmap in `FrameHolder`
- runs the native `shoot()` pipeline from that stored frame

Current plugin `ImageAnalysis` settings:

- preferred resolution: `VisionConfig.analysisWidth` x `VisionConfig.analysisHeight`
- fallback rule: closest higher, then lower
- backpressure strategy: `STRATEGY_KEEP_ONLY_LATEST`
- output format: `OUTPUT_IMAGE_FORMAT_RGBA_8888`
- analyzer executor: single background thread

The plugin path is the intended integration path for the Flutter app.

## Object detection pipeline

The project uses MediaPipe Object Detector in `IMAGE` mode through `ObjectDetectorHelper`.

Current detector settings:

- model asset: `efficientdet_lite0.tflite`
- max results: `VisionConfig.detectorMaxResults`
- score threshold: `VisionConfig.detectorScoreThreshold`
- running mode: `RunningMode.IMAGE`

Detection behavior:

1. The current upright bitmap is passed to MediaPipe.
2. MediaPipe returns detection results for the full frame.
3. The code keeps only detections whose top category is `person`.
4. Bounding boxes are returned in bitmap pixel coordinates.

## Image embedding pipeline

The project uses MediaPipe Image Embedder in `IMAGE` mode through `ImageEmbedderHelper`.

Current embedder settings:

- model asset: `mobilenet_v3_small.tflite`
- quantize: `false`
- L2 normalize: `true`
- running mode: `RunningMode.IMAGE`

Important embedder note:

- the embedder asset must be added manually to `app/src/main/assets/mobilenet_v3_small.tflite`
- `l2Normalize(true)` is intentionally enabled so cosine similarity can be computed as a dot product

Embedding flow:

1. A non-rejected crop is wrapped as an `MPImage`.
2. MediaPipe produces one or more embeddings.
3. The first float embedding is returned.

## Player registration system

The project includes an in-memory player embedding registry through `PlayerRegistry`.

Registry data model:

- `PlayerEmbedding`
  Contains a `playerId` plus the list of accepted embedding vectors collected for that player.

Registration flow in `PlayerRegistry.register(playerId, bitmaps)`:

1. For each candidate bitmap, run person detection.
2. If multiple people are found, keep the largest detected person box.
3. If no person is found, skip that bitmap.
4. Crop the selected person box.
5. If blur rejection is enabled and the crop is blurry, skip it.
6. Embed the crop.
7. Store the resulting `FloatArray`.
8. Merge all accepted embeddings into the registry under that `playerId`.

If every bitmap is skipped, `register(...)` throws `IllegalArgumentException`.

Dependency injection:

- `PlayerRegistry` does not create MediaPipe helpers itself
- `ObjectDetectorHelper` and `ImageEmbedderHelper` are injected into the registry during app or plugin startup

Serialization format:

- float vectors are serialized as JSON arrays of numbers
- the full registry is serialized as:
  `{ "playerId": [[0.1, 0.2, ...], [...]], "otherPlayer": [[...]] }`

Supported registry APIs:

- `register(playerId, bitmaps)`
- `importEmbeddings(json)`
- `exportEmbeddings(playerId)`
- `exportAll()`
- `getAll()`
- `clear()`
- `playerCount()`

## Identity matching

Identity matching is handled by `EmbeddingMatcher`.

Matching rule:

- every stored player can have multiple embeddings
- the query embedding is compared to every stored embedding for every player
- cosine similarity is computed as a dot product because embeddings are already L2-normalized
- each player's score is the maximum similarity across their stored embeddings
- the best overall player is accepted only if their score meets the threshold

Current default matcher threshold:

- `VisionConfig.matchThreshold`

If the best score is below threshold, the pipeline returns `Unknown`.

## Shoot pipeline

`ShootPipeline` owns the full shoot flow.

Dependencies injected into `ShootPipeline`:

- `ObjectDetectorHelper`
- `ImageEmbedderHelper`
- `FrameHolder`
- preview width supplier
- preview height supplier

`ShootResult` values:

- `Miss`
  No valid target was under the crosshair.
- `Unknown`
  A target path existed, but blur rejection, missing registrations, or failed identity matching prevented a confident identification.
- `Hit(playerId, confidence)`
  A registered player was matched with the given similarity score.

High-level shoot flow:

1. Read the latest frame from `FrameHolder`.
2. Run person detection.
3. Map candidate boxes into preview space.
4. Keep only boxes containing the centered crosshair.
5. If more than one box survives, choose the one whose center is closest to the crosshair center.
6. Crop the chosen image-space box.
7. Optionally reject blurry crops.
8. Embed the crop.
9. Match against `PlayerRegistry`.

The native test harness also renders the last mapped boxes and result state in `DetectionOverlayView`.

## Coordinate spaces

There are two important coordinate spaces:

- image space: pixel coordinates in the analyzed bitmap
- preview space: coordinates in the displayed preview surface

`CoordinateMapper` exists so overlay rendering and hit-testing can stay correct when those spaces differ because of scaling or cropping.

The current native test harness often stays close to a single visible space because it captures `PreviewView.bitmap`, but the plugin path uses a proper analysis bitmap and preview texture, so keeping mapping logic centralized is still the right long-term design.

## Crop extraction and blur rejection

After a target box is selected, `CropHelper` handles the next stage.

`cropPersonFromBitmap(...)`:

- clamps the chosen rectangle to bitmap bounds
- extracts the crop with `Bitmap.createBitmap(...)`

`isBlurry(...)`:

- converts the crop to grayscale
- computes a manual Laplacian response for every non-border pixel
- computes the variance of those responses
- treats the crop as blurry when the variance is below the configured threshold

If the crop is accepted in the native test harness, the app can save a debug JPEG crop to the app-specific external files directory.

## Settings you are likely to change

These settings are centralized in `VisionConfig.kt`:

- analysis resolution
  Change `analysisWidth` and `analysisHeight` to experiment with the speed/accuracy tradeoff in the Flutter plugin pipeline.
- detector model
  Change `detectorModelAssetPath` if you want to test a different MediaPipe-compatible object detection model.
- embedder model
  Change `embedderModelAssetPath` if you want to test a different MediaPipe-compatible image embedding model.
- detector result count
  Change `detectorMaxResults`.
- detector confidence threshold
  Change `detectorScoreThreshold`.
- match threshold
  Change `matchThreshold` to control how strict identity matching is.
  Lower values accept weaker matches. Higher values require stronger similarity.
- blur rejection enabled
  Change `enableBlurRejection` to `false` to skip blur rejection entirely.
- blur threshold
  Change `blurThreshold` to control how strict blur rejection is.
  Lower values reject fewer frames. Higher values reject more frames.

These settings still live outside `VisionConfig.kt`:

- camera lens
  Both entry points currently use `CameraSelector.DEFAULT_BACK_CAMERA`.
- native debug UI behavior
  `MainActivity` owns the temporary overlay/toast/log behavior used for testing.

## Flutter integration summary

Channel name:

- `com.yourteam.visionmodule/vision`

Exposed methods:

- `startPreview() -> Long textureId`
- `stopPreview() -> null`
- `registerPlayer({ playerId, imageBytes }) -> { storedCount }`
- `exportEmbeddings({ playerId }) -> String`
- `exportAll() -> String`
- `importEmbeddings({ json }) -> null`
- `shoot() -> { result, targetId?, confidence? }`
- `clearRegistrations() -> null`

Plugin registration:

- `VisionFlutterPlugin` implements `FlutterPlugin`
- because this repository is not packaged as a standalone Flutter pub plugin, the Flutter host should register it explicitly
- the host can call `VisionFlutterPlugin.registerWith(flutterEngine)` or add `VisionFlutterPlugin()` directly to `flutterEngine.plugins`

Read `flutter_integration.md` before wiring the Flutter side. That file is the integration contract for the Flutter developer.

## Practical guidance for future contributors

- Keep CameraX setup isolated and explicit. Small helper methods are preferred over large lifecycle methods.
- Avoid mixing ML logic directly into UI click handlers or channel handlers.
- Keep detector, embedder, matcher, and registry responsibilities separate.
- Keep one source of truth for tunable settings in `VisionConfig.kt`.
- Keep coordinate mapping centralized in `CoordinateMapper` so overlay rendering and hit-testing cannot drift apart.
- Keep the end-to-end shot flow inside `ShootPipeline` so activities and plugins stay thin.
- Keep Flutter integration concerns inside `VisionFlutterPlugin` instead of spreading channel logic across unrelated classes.
- If memory or latency becomes an issue later, profile first. The current goal is a correct end-to-end MVP, not a final performance pass.
