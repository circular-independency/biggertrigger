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
- `app/src/main/java/com/example/triggerroyale/CoordinateMapper.kt`
  Utility for mapping between image-space and preview-space rectangles. It is currently kept for future use if preview and analysis spaces diverge again.
- `app/src/main/java/com/example/triggerroyale/CropHelper.kt`
  Extracts person crops from the captured bitmap and rejects blurry crops using Laplacian variance.
- `app/src/main/java/com/example/triggerroyale/VisionConfig.kt`
  Central place for tunable detector settings such as model asset path, max results, and score threshold.
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
5. The detected rectangles are drawn directly on the debug overlay.
6. The center of the captured bitmap is treated as the crosshair point.
7. If no person is detected, the app shows `MISS – no person detected`.
8. If people are detected but the bitmap center is not inside any person box, the app shows `MISS` and logs a crosshair miss.
9. If multiple person boxes contain the bitmap center, the app picks the one whose center is closest to the bitmap center.
10. The chosen image-space box is cropped from the captured bitmap.
11. The crop is checked for blur using Laplacian variance.
12. If the crop is blurry, the app shows `UNKNOWN – blurry frame`.
13. If the crop is sharp enough, it is saved as a JPEG in the app-specific external files directory and the file path is logged.

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
- If memory pressure becomes an issue later, profile before optimizing. The current goal is a working end-to-end loop, not a final performance pass.
- If you add cropping, embedding, or server sync next, document where each stage runs and what coordinate space it expects.
