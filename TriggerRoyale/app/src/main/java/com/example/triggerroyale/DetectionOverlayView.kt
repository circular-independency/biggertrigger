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

    /** Paint used for the result label. */
    private val textPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.GREEN
        textSize = 18f * resources.displayMetrics.density
        style = Paint.Style.FILL
    }

    /** Latest detection boxes in preview/screen coordinates. */
    private var detections: List<RectF> = emptyList()

    /** Latest shoot result rendered on top of the debug rectangles. */
    private var shootResult: ShootResult? = null

    /**
     * Replaces the currently displayed detections and result overlay.
     *
     * @param boxes Detection boxes already mapped into preview/screen coordinates.
     * @param result Latest shoot result to render.
     */
    fun setOverlayState(boxes: List<RectF>, result: ShootResult?) {
        detections = boxes.map(::RectF)
        shootResult = result
        invalidate()
    }

    /** Clears all currently displayed boxes and result state. */
    fun clear() {
        detections = emptyList()
        shootResult = null
        invalidate()
    }

    /** Draws the currently stored detection rectangles and color-coded shoot result. */
    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)

        val overlayColor = when (shootResult) {
            is ShootResult.Miss -> Color.RED
            is ShootResult.Unknown -> Color.rgb(255, 165, 0)
            is ShootResult.Hit -> Color.GREEN
            null -> Color.GREEN
        }
        boxPaint.color = overlayColor
        textPaint.color = overlayColor

        detections.forEach { box ->
            canvas.drawRect(box, boxPaint)
        }

        val label = when (val result = shootResult) {
            ShootResult.Miss -> "MISS"
            ShootResult.Unknown -> "UNKNOWN"
            is ShootResult.Hit -> "${result.playerId} ${(result.confidence * 100f).toInt()}%"
            null -> null
        } ?: return

        canvas.drawText(label, LABEL_MARGIN_DP * resources.displayMetrics.density, textPaint.textSize + LABEL_MARGIN_DP * resources.displayMetrics.density, textPaint)
    }

    private companion object {
        private const val LABEL_MARGIN_DP = 16f
    }
}
