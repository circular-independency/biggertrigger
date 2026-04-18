package com.example.triggerroyale

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.util.AttributeSet
import android.view.View

/**
 * Debug overlay that renders object detection boxes on top of the camera preview.
 *
 * The incoming rectangles are already provided in preview/screen coordinates. This keeps the view
 * simple and ensures the user sees the same geometry that the hit logic uses.
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

    /** Latest detection boxes in preview/screen coordinates. */
    private var detections: List<RectF> = emptyList()

    /**
     * Replaces the currently displayed detections.
     *
     * @param boxes Detection boxes already mapped into preview/screen coordinates.
     */
    fun setDetections(boxes: List<RectF>) {
        detections = boxes.map(::RectF)
        invalidate()
    }

    /** Draws the currently stored detection rectangles directly in screen space. */
    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)

        if (detections.isEmpty()) {
            return
        }

        detections.forEach { box ->
            canvas.drawRect(box, boxPaint)
        }
    }
}
