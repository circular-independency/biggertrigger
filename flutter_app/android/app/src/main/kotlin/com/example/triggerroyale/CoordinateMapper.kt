package com.example.triggerroyale

import android.graphics.RectF
import kotlin.math.max

/**
 * Utility functions for converting rectangles between vision and UI coordinate spaces.
 *
 * MediaPipe detections are returned relative to the analyzed bitmap, while the player aims inside
 * `PreviewView`. This object keeps the center-crop mapping logic in one place so drawing and
 * hit-testing always use the same transformation.
 */
object CoordinateMapper {
    /**
     * Maps an image-space rectangle into preview-space using center-crop scaling.
     *
     * @param imageRect Rectangle in image pixel coordinates.
     * @param imageWidth Width of the analyzed bitmap.
     * @param imageHeight Height of the analyzed bitmap.
     * @param previewWidth Width of the current `PreviewView`.
     * @param previewHeight Height of the current `PreviewView`.
     * @return Rectangle in preview/screen coordinates, clamped to preview bounds.
     */
    fun imageRectToPreviewRect(
        imageRect: RectF,
        imageWidth: Int,
        imageHeight: Int,
        previewWidth: Int,
        previewHeight: Int
    ): RectF {
        if (imageWidth <= 0 || imageHeight <= 0 || previewWidth <= 0 || previewHeight <= 0) {
            return RectF()
        }

        val scale = max(
            previewWidth / imageWidth.toFloat(),
            previewHeight / imageHeight.toFloat()
        )
        val scaledWidth = imageWidth * scale
        val scaledHeight = imageHeight * scale
        val offsetX = (previewWidth - scaledWidth) / 2f
        val offsetY = (previewHeight - scaledHeight) / 2f

        val mappedRect = RectF(
            imageRect.left * scale + offsetX,
            imageRect.top * scale + offsetY,
            imageRect.right * scale + offsetX,
            imageRect.bottom * scale + offsetY
        )

        return RectF(
            mappedRect.left.coerceIn(0f, previewWidth.toFloat()),
            mappedRect.top.coerceIn(0f, previewHeight.toFloat()),
            mappedRect.right.coerceIn(0f, previewWidth.toFloat()),
            mappedRect.bottom.coerceIn(0f, previewHeight.toFloat())
        )
    }
}
