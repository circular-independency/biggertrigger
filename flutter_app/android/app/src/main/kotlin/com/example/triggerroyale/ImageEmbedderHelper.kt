package com.example.triggerroyale

import android.content.Context
import android.graphics.Bitmap
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.imageembedder.ImageEmbedder

/**
 * Small wrapper around MediaPipe's [ImageEmbedder].
 *
 * This keeps embedding setup and inference details out of `MainActivity`, so the activity can stay
 * focused on camera, targeting, and UI flow.
 *
 * @param context Any Android context. The application context is used internally so the embedder
 * can safely live for the duration of the activity.
 */
class ImageEmbedderHelper(context: Context) {
    /** MediaPipe embedder used for one-shot image embedding. */
    private val imageEmbedder: ImageEmbedder

    init {
        val options = ImageEmbedder.ImageEmbedderOptions.builder()
            .setBaseOptions(
                BaseOptions.builder()
                    .setModelAssetPath(VisionConfig.embedderModelAssetPath)
                    .build()
            )
            .setRunningMode(RunningMode.IMAGE)
            .setQuantize(false)
            .setL2Normalize(true)
            .build()

        imageEmbedder = ImageEmbedder.createFromOptions(context.applicationContext, options)
    }

    /**
     * Produces a floating-point embedding for the provided bitmap.
     *
     * @param bitmap Crop or image to embed.
     * @return First float embedding returned by MediaPipe.
     * @throws IllegalStateException when no embedding is returned.
     */
    fun embed(bitmap: Bitmap): FloatArray {
        val mpImage = BitmapImageBuilder(bitmap).build()
        val result = imageEmbedder.embed(mpImage)
        val embeddings = result.embeddingResult().embeddings()

        if (embeddings.isEmpty()) {
            throw IllegalStateException("Image embedder returned no embeddings.")
        }

        return embeddings[0].floatEmbedding()
    }

    /** Releases native MediaPipe resources. Must be called when the activity is destroyed. */
    fun close() {
        imageEmbedder.close()
    }
}
