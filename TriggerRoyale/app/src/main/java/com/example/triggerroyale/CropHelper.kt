package com.example.triggerroyale

import android.util.Log
import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.RectF
import kotlin.math.ceil
import kotlin.math.floor
import kotlin.math.max

/**
 * Utility functions for extracting and validating person crops.
 *
 * The current pipeline selects a person box, extracts that region from the latest upright bitmap,
 * and rejects the result if the crop is too blurry to be useful for later identification work.
 */

private const val TAG = "Blurry"
object CropHelper {
    /**
     * Extracts a person crop from the source bitmap using an image-space bounding box.
     *
     * The rectangle is clamped to the bitmap bounds before cropping so that slightly out-of-range
     * detector coordinates cannot crash the app.
     *
     * @param source Upright source bitmap.
     * @param boxInImageSpace Person box in image pixel coordinates.
     * @return Cropped bitmap for the selected person region.
     */
    fun cropPersonFromBitmap(source: Bitmap, boxInImageSpace: RectF): Bitmap {
        val left = floor(boxInImageSpace.left).toInt().coerceIn(0, source.width - 1)
        val top = floor(boxInImageSpace.top).toInt().coerceIn(0, source.height - 1)
        val right = ceil(boxInImageSpace.right).toInt().coerceIn(left + 1, source.width)
        val bottom = ceil(boxInImageSpace.bottom).toInt().coerceIn(top + 1, source.height)

        return Bitmap.createBitmap(source, left, top, right - left, bottom - top)
    }

    /**
     * Creates a downsampled version of a crop while preserving aspect ratio.
     *
     * If the source crop is already smaller than [targetLongEdgePx], the original bitmap is
     * returned unchanged (no upscaling).
     */
    fun downsampleCropForRegistration(source: Bitmap, targetLongEdgePx: Int): Bitmap {
        if (targetLongEdgePx <= 0) {
            return source
        }

        val currentLongEdge = max(source.width, source.height)
        if (currentLongEdge <= targetLongEdgePx) {
            return source
        }

        val scale = targetLongEdgePx.toFloat() / currentLongEdge.toFloat()
        val targetWidth = max(1, (source.width * scale).toInt())
        val targetHeight = max(1, (source.height * scale).toInt())
        return Bitmap.createScaledBitmap(source, targetWidth, targetHeight, true)
    }


    /**
     * Rejects blurry crops using a simple manually computed Laplacian variance score.
     *
     * Higher variance usually means the crop contains more edge detail and is therefore sharper.
     *
     * @param bitmap Crop to evaluate.
     * @param threshold Variance threshold below which the crop is treated as blurry.
     * @return `true` if the crop is blurry, `false` otherwise.
     */
    fun isBlurry(bitmap: Bitmap, threshold: Double = 80.0): Boolean {
        val width = bitmap.width
        val height = bitmap.height

        if (width < 3 || height < 3) {
            return true
        }

        val pixels = IntArray(width * height)
        bitmap.getPixels(pixels, 0, width, 0, 0, width, height)

        val grayscale = IntArray(width * height)
        for (index in pixels.indices) {
            val color = pixels[index]
            grayscale[index] = (
                0.299 * Color.red(color) +
                    0.587 * Color.green(color) +
                    0.114 * Color.blue(color)
                ).toInt()
        }

        val laplacianValues = DoubleArray((width - 2) * (height - 2))
        var laplacianIndex = 0

        for (y in 1 until height - 1) {
            for (x in 1 until width - 1) {
                val centerIndex = y * width + x
                val center = grayscale[centerIndex]
                val top = grayscale[centerIndex - width]
                val bottom = grayscale[centerIndex + width]
                val left = grayscale[centerIndex - 1]
                val right = grayscale[centerIndex + 1]

                laplacianValues[laplacianIndex++] =
                    kotlin.math.abs((4 * center - top - bottom - left - right).toDouble())
            }
        }

        val mean = laplacianValues.average()
        val variance = laplacianValues.sumOf { value ->
            val difference = value - mean
            difference * difference
        } / laplacianValues.size

        Log.d(TAG, "Variance: ${variance}")

        return variance < threshold
    }
}
