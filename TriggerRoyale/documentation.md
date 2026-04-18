# TriggerRoyale Android Vision Notes

This repository currently contains the native Android MVP for the Kotlin vision module that will later be exposed to Flutter as a plugin. The current app is intentionally small: it opens the back camera, shows a preview, draws a crosshair overlay, grabs the current preview frame when the `SHOOT` button is pressed, runs person detection on that frame, chooses the person box under the centered crosshair, extracts a debug body crop, rejects blurry crops, and saves sharp crops for inspection.

## Current structure

- `app/src/main/java/com/example/triggerroyale/MainActivity.kt`
  Owns camera permission handling, CameraX preview setup, detector lifecycle, hit-testing, crop saving, and the temporary `SHOOT` button behavior.
- `app/src/main/java/com/example/triggerroyale/CrosshairOverlayView.kt`
  Draws the crosshair overlay on top of the preview.
- `app/src/main/java/com/example/triggerroyale/DetectionOverlayView.kt`
  Draws debug detection rectangles in preview/screen coordinates.
- `app/src/main/java/com/example/triggerroyale/ObjectDetectorHelper.kt`
  Wraps MediaPipe Object Detector setup and image-mode inference.
- `app/src/main/java/com/example/triggerroyale/ImageEmbedderHelper.kt`
  Wraps MediaPipe Image Embedder setup and one-shot embedding inference.
- `app/src/main/java/com/example/triggerroyale/PlayerEmbedding.kt`
  Simple data model describing one player's collected embeddings.
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
  Utility for mapping between image-space and preview-space rectangles. It is currently kept for future use if preview and analysis spaces diverge again.
- `app/src/main/java/com/example/triggerroyale/CropHelper.kt`
  Extracts person crops from the captured bitmap and rejects blurry crops using Laplacian variance.
- `app/src/main/java/com/example/triggerroyale/VisionConfig.kt`
  Central place for tunable detector/embedder settings such as model asset paths, max results, score threshold, and blur rejection options.
- `app/src/main/res/layout/activity_main.xml`
  Defines the preview, debug detection overlay, crosshair overlay, and `SHOOT` button.
- `app/build.gradle.kts`
  Holds Android and dependency configuration, including CameraX and MediaPipe Tasks.

## Camera pipeline

`MainActivity` currently binds one CameraX use case:

- `Preview`
  Sends frames to `PreviewView` so the player can aim.

The shoot pipeline grabs the current frame directly from `PreviewView.bitmap`.

Why the app uses `PreviewView.bitmap` right now:

- it keeps detection, hit-testing, cropping, and the visible preview in one coordinate space
- it avoids continuous `ImageProxy` to `Bitmap` conversion on every frame
- it avoids noisy gralloc errors seen on some Mali devices in the continuous conversion path

This is a practical MVP choice. A future plugin version can move back to a dedicated analysis pipeline if it becomes necessary for performance or direct ML input handling.

## Object detection pipeline

The project uses MediaPipe Object Detector in `IMAGE` mode through `ObjectDetectorHelper`.

Current detector settings:

- Model asset: `efficientdet_lite0.tflite`
- Max results: `10`
- Score threshold: `0.4`
- Running mode: `RunningMode.IMAGE`

When `SHOOT` is pressed:

1. The current preview bitmap is read from `PreviewView.bitmap`.
2. Detection runs on `Dispatchers.Default`.
3. MediaPipe returns detection results for the full frame.
4. The code keeps only detections whose top category is `person`.
5. The image-space boxes are mapped into preview-space through `CoordinateMapper`.
6. The crosshair center is the middle of the preview.
7. If the crosshair is not inside any mapped box, the shot is `Miss`.
8. If multiple mapped boxes overlap the crosshair, the pipeline picks the box whose center is closest to the crosshair center.
9. The chosen image-space box is cropped from the original bitmap.
10. If blur rejection is enabled and the crop is blurry, the result is `Unknown`.
11. The crop is embedded with MediaPipe Image Embedder.
12. If no players are registered, the result is `Unknown`.
13. The query embedding is matched against `PlayerRegistry` with cosine similarity.
14. If the best score meets the matcher threshold, the result is `Hit(playerId, confidence)`.
15. Otherwise, the result is `Unknown`.

## Image embedding pipeline

The project uses MediaPipe Image Embedder in `IMAGE` mode through `ImageEmbedderHelper`.

Current embedder settings:

- Model asset: `mobilenet_v3_small.tflite`
- Quantize: `false`
- L2 normalize: `true`
- Running mode: `RunningMode.IMAGE`

Important embedder note:

- The embedder asset must be added manually to `app/src/main/assets/mobilenet_v3_small.tflite`.
- `l2Normalize(true)` is intentionally enabled so cosine similarity can later be computed as a simple dot product.

Embedding flow:

1. A non-blurry crop is wrapped as an `MPImage`.
2. MediaPipe produces one or more embeddings.
3. The first float embedding is returned.
4. The app logs the embedding vector size and shows a success toast.

## Player registration system

The project now includes an in-memory player embedding registry through `PlayerRegistry`.

Registry data model:

- `PlayerEmbedding`
  Contains a `playerId` plus the list of accepted embedding vectors collected for that player.

Registration flow in `PlayerRegistry.register(playerId, bitmaps)`:

1. For each candidate bitmap, run person detection.
2. If multiple people are found, keep the largest detected person box.
3. If no person is found, skip that bitmap.
4. Crop the selected person box.
5. If the crop is blurry, skip it.
6. Embed the crop.
7. Store the resulting `FloatArray`.
8. Merge all accepted embeddings into the registry under that `playerId`.

If every bitmap is skipped, `register(...)` throws `IllegalArgumentException`.

Dependency injection:

- `PlayerRegistry` does not create MediaPipe helpers itself.
- `ObjectDetectorHelper` and `ImageEmbedderHelper` are injected into the registry as `lateinit` vars during app startup.
- `MainActivity` assigns those dependencies when each helper initializes successfully.

Serialization format:

- Float vectors are serialized as JSON arrays of numbers.
- The full registry is serialized as:
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

- `VisionConfig.matchThreshold` (currently `0.30`)

If the best score is below threshold, the pipeline returns `Unknown`.

## Shoot pipeline

The app now uses `ShootPipeline` to own the full shoot flow.

Dependencies injected into `ShootPipeline`:

- `ObjectDetectorHelper`
- `ImageEmbedderHelper`
- `FrameHolder`
- preview width supplier
- preview height supplier

`FrameHolder` currently stores the latest `PreviewView.bitmap` captured by `MainActivity` when the player presses `SHOOT`.

`ShootResult` values:

- `Miss`
  No valid target was under the crosshair.
- `Unknown`
  A target path existed, but blur rejection, missing registrations, or failed identity matching prevented a confident identification.
- `Hit(playerId, confidence)`
  A registered player was matched with the given similarity score.

UI rendering:

- `Miss` is shown in red.
- `Unknown` is shown in orange.
- `Hit` is shown in green with the player id and confidence.
- The debug overlay uses the mapped preview-space rectangles from the pipeline's latest run.

## Coordinate spaces

The current MVP deliberately keeps everything in one coordinate space:

- the player sees `PreviewView`
- `PreviewView.bitmap` captures that same displayed frame
- MediaPipe runs on that captured bitmap
- hit-testing is done against boxes from that bitmap
- crop extraction uses that same bitmap

That means the current pipeline does not need preview-to-image coordinate conversion for hit-testing.

`CoordinateMapper` is still kept in the project because it will become useful again if:

- the crosshair is no longer fixed at center
- the app returns to a separate `ImageAnalysis` pipeline
- future ML stages run on a frame whose coordinate space differs from the displayed preview

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

Current blur threshold:

- `80.0`

If the crop is sharp enough, the app saves it as:

- `debug_crop_<timestamp>.jpg`

Location:

- app-specific external files directory from `getExternalFilesDir(null)`

This saved file is only for debugging right now. It gives developers a direct way to inspect what future embedding logic would receive.

## Settings you are likely to change

These settings are centralized in `VisionConfig.kt`:

- Detector model
  Change `detectorModelAssetPath` if you want to test a different MediaPipe-compatible object detection model.
- Embedder model
  Change `embedderModelAssetPath` if you want to test a different MediaPipe-compatible image embedding model.
- Detector result count
  Change `detectorMaxResults`.
- Detector confidence threshold
  Change `detectorScoreThreshold`.
- Blur rejection enabled
  Change `enableBlurRejection` to `false` if you want to skip blur rejection entirely.
- Blur threshold
  Change `blurThreshold` to control how strict blur rejection is.
  Lower values reject fewer frames. Higher values reject more frames.

These settings still live in `MainActivity.kt`:

- Camera lens
  Replace `CameraSelector.DEFAULT_BACK_CAMERA` if front camera support is ever needed.
- Hit-selection behavior
  The current target-selection rule is: choose the overlapping box whose center is closest to the bitmap center.
- Debug crop quality
  Change `DEBUG_CROP_JPEG_QUALITY` in `MainActivity.kt` if you want smaller or larger debug files.

## Planned evolution toward the Flutter plugin

The long-term architecture is still for the Kotlin module to own:

- CameraX lifecycle
- Preview surface or texture output
- Frame analysis or capture pipeline
- `shoot()` entrypoint

Flutter will eventually own UI composition and call into the Kotlin side through a plugin or platform channel. The current native screen is just a test harness for validating the vision loop before the Flutter integration is added.

## Practical guidance for future contributors

- Keep CameraX setup isolated and explicit. Small helper methods are preferred over large lifecycle methods.
- Avoid mixing ML logic directly into UI click handlers.
- Keep preview capture, target detection, and crop extraction separate from future embedding logic.
- Keep coordinate mapping centralized in `CoordinateMapper` so overlay rendering and future hit-testing cannot drift apart.
- Keep one source of truth for tunable settings in `VisionConfig.kt` so experiments stay easy to reason about.
- Keep crop extraction and blur scoring inside `CropHelper` so future embedding code can stay focused on identification.
- Keep registration and JSON serialization concerns inside `PlayerRegistry` so UI or networking code can stay thin.
- Keep similarity logic inside `EmbeddingMatcher` so matching policy changes stay isolated.
- Keep the end-to-end shot flow inside `ShootPipeline` so `MainActivity` remains a thin UI/controller layer.
- Keep detection and embedding wrappers separate so model-specific MediaPipe details stay out of `MainActivity`.
- If memory pressure becomes an issue later, profile before optimizing. The current goal is a working end-to-end loop, not a final performance pass.
- If you add cropping, embedding, or server sync next, document where each stage runs and what coordinate space it expects.
