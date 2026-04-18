package com.example.triggerroyale

import android.graphics.PointF
import android.graphics.RectF
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlin.math.hypot

/**
 * End-to-end shoot pipeline.
 *
 * This class owns the sequence:
 * frame -> detect -> crosshair filter -> crop -> blur check -> embed -> match
 *
 * `MainActivity` is responsible for putting the latest frame into `frameHolder` and rendering the
 * returned result and debug boxes.
 */
class ShootPipeline(
    private val detectorHelper: ObjectDetectorHelper,
    private val embedderHelper: ImageEmbedderHelper,
    private val frameHolder: FrameHolder,
    private val previewWidth: () -> Int,
    private val previewHeight: () -> Int
) {
    /** Latest mapped preview-space boxes from the last shoot call, for debug overlay rendering. */
    var lastMappedBoxes: List<RectF> = emptyList()
        private set

    /**
     * Runs the full shoot pipeline.
     *
     * This function switches to `Dispatchers.Default` internally so it can safely be called from the
     * main thread.
     */
    suspend fun shoot(): ShootResult = withContext(Dispatchers.Default) {
        val bitmap = frameHolder.getLatest() ?: return@withContext ShootResult.Miss

        val currentPreviewWidth = previewWidth()
        val currentPreviewHeight = previewHeight()
        if (currentPreviewWidth <= 0 || currentPreviewHeight <= 0) {
            lastMappedBoxes = emptyList()
            return@withContext ShootResult.Miss
        }

        val imageBoxes = detectorHelper.detect(bitmap)
        if (imageBoxes.isEmpty()) {
            lastMappedBoxes = emptyList()
            return@withContext ShootResult.Miss
        }

        val mappedPairs = imageBoxes.map { imageBox ->
            imageBox to CoordinateMapper.imageRectToPreviewRect(
                imageRect = imageBox,
                imageWidth = bitmap.width,
                imageHeight = bitmap.height,
                previewWidth = currentPreviewWidth,
                previewHeight = currentPreviewHeight
            )
        }
        lastMappedBoxes = mappedPairs.map { it.second }

        val crosshairCenter = PointF(currentPreviewWidth / 2f, currentPreviewHeight / 2f)
        val hitPairs = mappedPairs.filter { (_, mappedBox) ->
            mappedBox.contains(crosshairCenter.x, crosshairCenter.y)
        }

        if (hitPairs.isEmpty()) {
            return@withContext ShootResult.Miss
        }

        val chosenPair = hitPairs.minByOrNull { (_, mappedBox) ->
            distanceBetweenCenters(mappedBox, crosshairCenter)
        } ?: return@withContext ShootResult.Miss

        val chosenImageBox = chosenPair.first
        val crop = CropHelper.cropPersonFromBitmap(bitmap, chosenImageBox)
        if (VisionConfig.enableBlurRejection &&
            CropHelper.isBlurry(crop, VisionConfig.blurThreshold)
        ) {
            return@withContext ShootResult.Unknown
        }

        val embedding = embedderHelper.embed(crop)
        if (PlayerRegistry.playerCount() == 0) {
            return@withContext ShootResult.Unknown
        }

        val match = EmbeddingMatcher.findBestMatch(
            queryEmbedding = embedding,
            registry = PlayerRegistry.getAll(),
            threshold = VisionConfig.matchThreshold
        )
        return@withContext if (match != null) {
            ShootResult.Hit(match.first, match.second)
        } else {
            ShootResult.Unknown
        }
    }

    /** Computes center-to-center distance for crosshair tie-breaking. */
    private fun distanceBetweenCenters(box: RectF, point: PointF): Double {
        return hypot((box.centerX() - point.x).toDouble(), (box.centerY() - point.y).toDouble())
    }
}
