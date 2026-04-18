package com.example.triggerroyale

import android.content.Context
import android.graphics.Bitmap
import android.graphics.RectF
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.objectdetector.ObjectDetector

/**
 * Small wrapper around MediaPipe's [ObjectDetector].
 *
 * This keeps model setup and inference details out of [MainActivity], so the activity can focus on
 * camera lifecycle and UI behavior.
 *
 * @param context Any Android context. The application context is used internally so the detector
 * can outlive a single view reference safely during the activity lifetime.
 */
class ObjectDetectorHelper(context: Context) {
    /** Lazily configured MediaPipe detector used for one-shot image inference. */
    private val objectDetector: ObjectDetector

    init {
        // MediaPipe IMAGE mode is the correct mode for single bitmap inference triggered by shoot().
        val options = ObjectDetector.ObjectDetectorOptions.builder()
            .setBaseOptions(
                BaseOptions.builder()
                    .setModelAssetPath(VisionConfig.detectorModelAssetPath)
                    .build()
            )
            .setRunningMode(RunningMode.IMAGE)
            .setMaxResults(VisionConfig.detectorMaxResults)
            .setScoreThreshold(VisionConfig.detectorScoreThreshold)
            .build()

        objectDetector = ObjectDetector.createFromOptions(context.applicationContext, options)
    }

    /**
     * Detects people in the provided bitmap.
     *
     * The detector is run on the full upright bitmap. Only detections whose highest-ranked
     * category is `person` are returned.
     *
     * @param bitmap Upright ARGB bitmap to process.
     * @return A list of person bounding boxes in bitmap pixel coordinates.
     */
    fun detect(bitmap: Bitmap): List<RectF> {
        val mpImage = BitmapImageBuilder(bitmap).build()
        val result = objectDetector.detect(mpImage)

        return result.detections()
            .mapNotNull { detection ->
                // MediaPipe returns categories sorted by confidence, so the first category is top-1.
                val topCategory = detection.categories().firstOrNull() ?: return@mapNotNull null
                if (!topCategory.categoryName().equals(PERSON_CATEGORY, ignoreCase = true)) {
                    return@mapNotNull null
                }

                // The Android MediaPipe API already returns bounding boxes in image pixel space.
                RectF(detection.boundingBox())
            }
    }

    /** Releases native MediaPipe resources. Must be called when the activity is destroyed. */
    fun close() {
        objectDetector.close()
    }

    private companion object {
        /** COCO label expected from the selected object detector model for human detections. */
        private const val PERSON_CATEGORY = "person"
    }
}
