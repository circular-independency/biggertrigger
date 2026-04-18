# TriggerRoyale Android Vision Notes

This repository currently contains the native Android MVP for the Kotlin vision module that will later be exposed to Flutter as a plugin. The current app is intentionally small: it opens the back camera, shows a preview, draws a crosshair overlay, keeps the most recent analyzed frame in memory, and lets the `SHOOT` button read that cached frame.

## Current structure

- `app/src/main/java/com/example/triggerroyale/MainActivity.kt`
  Owns camera permission handling, CameraX setup, preview binding, frame analysis, and the temporary `SHOOT` button behavior.
- `app/src/main/java/com/example/triggerroyale/CrosshairOverlayView.kt`
  Draws the crosshair overlay on top of the preview.
- `app/src/main/res/layout/activity_main.xml`
  Defines the preview, crosshair overlay, and `SHOOT` button.
- `app/build.gradle.kts`
  Holds Android and dependency configuration, including CameraX and MediaPipe Tasks.

## Camera pipeline

`MainActivity` binds two CameraX use cases at the same time:

- `Preview`
  Sends frames to `PreviewView` so the player can aim.
- `ImageAnalysis`
  Produces RGBA frames for the future vision pipeline.

The analysis use case is configured as follows:

- Resolution: `640 x 480`
- Backpressure: `ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST`
- Output format: `ImageAnalysis.OUTPUT_IMAGE_FORMAT_RGBA_8888`
- Analyzer thread: `Executors.newSingleThreadExecutor()`

Inside the analyzer:

1. The incoming `ImageProxy` is converted to a `Bitmap` immediately with `toBitmap()`.
2. The `ImageProxy` is closed immediately after conversion.
3. The bitmap is rotated using `imageInfo.rotationDegrees` so the cached frame is always upright.
4. The rotated bitmap is stored in `latestFrame`, an `AtomicReference<Bitmap?>`.

This is the only shared frame state right now. The `SHOOT` button reads `latestFrame`. If a frame is available, the app logs its size. If not, it shows `No frame yet`.

## Why the analyzer closes the proxy immediately

This is critical with CameraX. Holding an `ImageProxy` open blocks the analysis pipeline and eventually stalls frame delivery. Any future vision code should continue this rule:

- Copy out what is needed from the proxy immediately.
- Close the proxy immediately.
- Do all additional work on the copied data, not on the proxy.

## Settings you are likely to change

These settings all live in `MainActivity.kt` today:

- Analysis resolution
  Change the `Size(640, 480)` inside `buildImageAnalysis()`.
- Resolution fallback behavior
  Change the `ResolutionStrategy` fallback rule if a stricter or looser match is needed.
- Camera lens
  Replace `CameraSelector.DEFAULT_BACK_CAMERA` if front camera support is ever needed.
- Analyzer threading
  Replace the single-thread executor only if there is a measured reason. The current setup is simple and predictable.

## Planned evolution toward the Flutter plugin

The long-term architecture is for the Kotlin module to own:

- CameraX lifecycle
- Preview surface or texture output
- Frame analysis pipeline
- `shoot()` entrypoint

Flutter will eventually own UI composition and call into the Kotlin side through a plugin or platform channel. The current native screen is just a test harness for validating the vision loop before the Flutter integration is added.

## Practical guidance for future contributors

- Keep CameraX setup isolated and explicit. Small helper methods are preferred over large lifecycle methods.
- Avoid mixing ML logic directly into UI click handlers.
- Keep bitmap rotation and frame caching separate from future target detection and embedding logic.
- If memory pressure becomes an issue later, profile before optimizing. The current goal is a working end-to-end loop, not a final performance pass.
- If you add MediaPipe or identification code, document where it runs and what data contract it expects from `latestFrame`.
