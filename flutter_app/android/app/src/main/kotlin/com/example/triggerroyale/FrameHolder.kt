package com.example.triggerroyale

import android.graphics.Bitmap
import java.util.concurrent.atomic.AtomicReference

/**
 * Thread-safe holder for the latest frame used by the shoot pipeline.
 *
 * In the current MVP the activity captures `PreviewView.bitmap` on button press and stores it here
 * before delegating to `ShootPipeline`.
 */
class FrameHolder {
    private val latestFrame = AtomicReference<Bitmap?>(null)

    /** Replaces the stored frame. */
    fun setLatest(bitmap: Bitmap?) {
        latestFrame.set(bitmap)
    }

    /** Returns the currently stored frame, or `null` when none is available. */
    fun getLatest(): Bitmap? = latestFrame.get()
}
