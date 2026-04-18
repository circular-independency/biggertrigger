package com.example.triggerroyale

import android.util.Size

/**
 * Central place for tunable vision settings.
 *
 * Keeping these values together makes it easy to experiment with the speed/accuracy tradeoff
 * without searching through camera or ML code.
 */
object VisionConfig {
    /**
     * Resolution requested from CameraX for the analysis pipeline.
     *
     * This affects the size of the bitmap stored in [MainActivity.latestFrame] after rotation.
     * Lower values are usually faster, while higher values can improve detection quality.
     */
    val analysisResolution: Size = Size(640, 480)

    /** Asset path of the MediaPipe-compatible object detection model in `app/src/main/assets`. */
    const val detectorModelAssetPath = "efficientdet_lite0.tflite"

    /** Maximum number of detections MediaPipe should return for a single image. */
    const val detectorMaxResults = 10

    /** Minimum confidence score a detection must have to be returned by MediaPipe. */
    const val detectorScoreThreshold = 0.4f
}
