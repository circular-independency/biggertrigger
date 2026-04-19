package com.example.triggerroyale

/**
 * Central place for tunable vision settings.
 *
 * Keeping these values together makes it easy to experiment with the speed/accuracy tradeoff
 * without searching through camera or ML code.
 */
object VisionConfig {
    /** Radius in pixels around frame center treated as crosshair hit zone. */
    const val crosshairRadiusPx = 60f

    /**
     * When enabled, registration stores an additional embedding from a downsampled person crop.
     *
     * This helps matching distant/small targets by adding low-detail examples to the registry.
     */
    const val enableDownsampledRegistrationEmbedding = true

    /**
     * Target long-edge size (in pixels) for registration downsample embedding variant.
     *
     * The crop keeps its aspect ratio and is only scaled down (never upscaled).
     */
    const val registrationDownsampleLongEdgePx = 96

    /**
     * Target long-edge size (in pixels) for the second registration downsample pass.
     *
     * This should be smaller than [registrationDownsampleLongEdgePx].
     */
    const val registrationSecondDownsampleLongEdgePx = 64

    /** Preferred ImageAnalysis width used by the Flutter plugin preview pipeline. */
    const val analysisWidth = 640

    /** Preferred ImageAnalysis height used by the Flutter plugin preview pipeline. */
    const val analysisHeight = 480

    /** Asset path of the MediaPipe-compatible object detection model in `app/src/main/assets`. */
    const val detectorModelAssetPath = "efficientdet_lite0.tflite"

    /**
     * Asset path of the MediaPipe-compatible image embedding model in `app/src/main/assets`.
     *
     * Developer action required: this file must be added manually to:
     * `app/src/main/assets/mobilenet_v3_small.tflite`
     */
    //const val embedderModelAssetPath = "mobilenet_v3_small.tflite"
    const val embedderModelAssetPath = "mobilenet_v3_large.tflite"

    /** Maximum number of detections MediaPipe should return for a single image. */
    const val detectorMaxResults = 10

    /** Minimum confidence score a detection must have to be returned by MediaPipe. */
    const val detectorScoreThreshold = 0.4f

    /**
     * Minimum cosine-similarity score required to accept an identity match.
     *
     * Lower values make matching more permissive. Higher values make matching stricter.
     */
    const val matchThreshold = 0.15f

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
