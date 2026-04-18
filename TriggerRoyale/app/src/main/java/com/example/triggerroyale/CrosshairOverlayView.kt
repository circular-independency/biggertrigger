package com.example.triggerroyale

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.util.AttributeSet
import android.view.View

class CrosshairOverlayView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0
) : View(context, attrs, defStyleAttr) {

    private val density = resources.displayMetrics.density
    private val lineLengthPx = 60f * density
    private val halfLineLengthPx = lineLengthPx / 2f
    private val circleRadiusPx = 6f * density
    private val strokeWidthPx = 2f * density

    private val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.WHITE
        style = Paint.Style.STROKE
        strokeWidth = strokeWidthPx
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)

        val centerX = width / 2f
        val centerY = height / 2f

        canvas.drawLine(
            centerX - halfLineLengthPx,
            centerY,
            centerX + halfLineLengthPx,
            centerY,
            paint
        )
        canvas.drawLine(
            centerX,
            centerY - halfLineLengthPx,
            centerX,
            centerY + halfLineLengthPx,
            paint
        )
        canvas.drawCircle(centerX, centerY, circleRadiusPx, paint)
    }
}
