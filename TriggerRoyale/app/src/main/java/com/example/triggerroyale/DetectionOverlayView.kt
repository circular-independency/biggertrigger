package com.example.triggerroyale

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.util.AttributeSet
import android.view.View
import kotlin.math.max

/**
 * Debug overlay that renders object detection boxes on top of the camera preview.
 *
 * The incoming rectangles are provided in source-image coordinates. This view maps them onto the
 * screen using the same center-crop style scaling as the current `PreviewView` configuration.
 */
class DetectionOverlayView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0
) : View(context, attrs, defStyleAttr) {

    /** Stroke thickness used for the debug rectangles. */
    private val strokeWidthPx = 3f * resources.displayMetrics.density

    /** Paint used to draw detection rectangles. */
    private val boxPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.GREEN
        style = Paint.Style.STROKE
        strokeWidth = strokeWidthPx
    }

    /** Width of the source image the current detections were produced from. */
    private var sourceImageWidth = 0

    /** Height of the source image the current detections were produced from. */
    private var sourceImageHeight = 0

    /** Latest detection boxes in source-image pixel coordinates. */
    private var detections: List<RectF> = emptyList()

    /**
     * Replaces the currently displayed detections.
     *
     * @param imageWidth Width of the bitmap used for detection.
     * @param imageHeight Height of the bitmap used for detection.
     * @param boxes Detection boxes in bitmap pixel coordinates.
     */
    fun setDetections(imageWidth: Int, imageHeight: Int, boxes: List<RectF>) {
        sourceImageWidth = imageWidth
        sourceImageHeight = imageHeight
        detections = boxes.map(::RectF)
        invalidate()
    }

    /** Draws the currently stored detections mapped from bitmap space into view space. */
    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)

        if (sourceImageWidth <= 0 || sourceImageHeight <= 0 || detections.isEmpty()) {
            return
        }

        // Match PreviewView's fill-center behavior by scaling until the full view is covered.
        val scale = max(
            width / sourceImageWidth.toFloat(),
            height / sourceImageHeight.toFloat()
        )
        val scaledWidth = sourceImageWidth * scale
        val scaledHeight = sourceImageHeight * scale
        val offsetX = (width - scaledWidth) / 2f
        val offsetY = (height - scaledHeight) / 2f

        detections.forEach { box ->
            // Convert from source-image pixels into this overlay's on-screen coordinate system.
            val mappedBox = RectF(
                box.left * scale + offsetX,
                box.top * scale + offsetY,
                box.right * scale + offsetX,
                box.bottom * scale + offsetY
            )

            canvas.drawRect(mappedBox, boxPaint)
        }
    }
}
