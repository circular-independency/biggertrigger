package com.example.triggerroyale

/**
 * Central place for tunable vision settings.
 *
 * Keeping these values together makes it easy to experiment with the speed/accuracy tradeoff
 * without searching through camera or ML code.
 */
object VisionConfig {
    /** Asset path of the MediaPipe-compatible object detection model in `app/src/main/assets`. */
    const val detectorModelAssetPath = "efficientdet_lite0.tflite"

    /**
     * Asset path of the MediaPipe-compatible image embedding model in `app/src/main/assets`.
     *
     * Developer action required: this file must be added manually to:
     * `app/src/main/assets/mobilenet_v3_small.tflite`
     */
    const val embedderModelAssetPath = "mobilenet_v3_small.tflite"

    /** Maximum number of detections MediaPipe should return for a single image. */
    const val detectorMaxResults = 10

    /** Minimum confidence score a detection must have to be returned by MediaPipe. */
    const val detectorScoreThreshold = 0.4f

    /**
     * Enables blur rejection for extracted crops.
     *
     * Set this to `false` to always accept the crop even when it has very low edge detail.
     */
    const val enableBlurRejection = false

    /**
     * Laplacian variance threshold used by [CropHelper.isBlurry].
     *
     * Lower values reject fewer frames. Higher values reject more aggressively.
     */
    const val blurThreshold = 50.0
}
