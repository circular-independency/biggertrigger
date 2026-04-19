package com.example.triggerroyale

import android.graphics.Bitmap
import android.graphics.RectF
import org.json.JSONArray
import org.json.JSONObject

/**
 * In-memory registry of player embeddings.
 *
 * The registry does not create MediaPipe helpers itself. Instead, the app injects the already
 * initialized helpers during startup so all registration code uses the same detector/embedder
 * configuration as the rest of the app.
 */
object PlayerRegistry {
    /** Detector dependency that must be assigned during app startup before calling `register()`. */
    lateinit var objectDetectorHelper: ObjectDetectorHelper

    /** Embedder dependency that must be assigned during app startup before calling `register()`. */
    lateinit var imageEmbedderHelper: ImageEmbedderHelper

    /** Internal mutable storage keyed by player id. */
    private val registry = mutableMapOf<String, MutableList<FloatArray>>()

    /**
     * Registers a player from a set of candidate bitmaps.
     *
     * For each bitmap, the registry:
     * 1. detects people
     * 2. keeps only the largest detected person box
     * 3. crops that box
     * 4. rejects blurry crops
     * 5. embeds the accepted crop
     *
     * @param playerId Stable identifier of the player being registered.
     * @param bitmaps Candidate registration images.
     * @return The collected embeddings for the player.
     * @throws IllegalArgumentException if no valid embedding could be produced.
     */
    fun register(playerId: String, bitmaps: List<Bitmap>): PlayerEmbedding {
        checkDependencies()

        val collectedEmbeddings = mutableListOf<FloatArray>()

        bitmaps.forEach { bitmap ->
            val personBox = objectDetectorHelper.detect(bitmap)
                .maxByOrNull(::rectArea)
                ?: return@forEach

            val crop = CropHelper.cropPersonFromBitmap(bitmap, personBox)
            if (CropHelper.isBlurry(crop, VisionConfig.blurThreshold)) {
                return@forEach
            }

            collectedEmbeddings += imageEmbedderHelper.embed(crop)

            if (VisionConfig.enableDownsampledRegistrationEmbedding) {
                val downsampledCropPass1 = CropHelper.downsampleCropForRegistration(
                    source = crop,
                    targetLongEdgePx = VisionConfig.registrationDownsampleLongEdgePx
                )
                val pass1WasDownsampled =
                    downsampledCropPass1.width != crop.width ||
                        downsampledCropPass1.height != crop.height
                if (pass1WasDownsampled) {
                    collectedEmbeddings += imageEmbedderHelper.embed(downsampledCropPass1)

                    val downsampledCropPass2 = CropHelper.downsampleCropForRegistration(
                        source = downsampledCropPass1,
                        targetLongEdgePx = VisionConfig.registrationSecondDownsampleLongEdgePx
                    )
                    val pass2WasDownsampled =
                        downsampledCropPass2.width != downsampledCropPass1.width ||
                            downsampledCropPass2.height != downsampledCropPass1.height
                    if (pass2WasDownsampled) {
                        collectedEmbeddings += imageEmbedderHelper.embed(downsampledCropPass2)
                        downsampledCropPass2.recycle()
                    }

                    downsampledCropPass1.recycle()
                }
            }
        }

        if (collectedEmbeddings.isEmpty()) {
            throw IllegalArgumentException(
                "Player '$playerId' produced no valid embeddings from the provided bitmaps."
            )
        }

        val storedEmbeddings = registry.getOrPut(playerId) { mutableListOf() }
        storedEmbeddings += collectedEmbeddings

        return PlayerEmbedding(playerId, collectedEmbeddings.toList())
    }

    /**
     * Imports a JSON registry blob and merges it into the existing in-memory registry.
     *
     * Expected format:
     * `{ "playerId": [[0.1, 0.2], [0.3, 0.4]], "otherPlayer": [[...]] }`
     *
     * @param json Serialized registry blob.
     */
    fun importEmbeddings(json: String) {
        val root = JSONObject(json)

        root.keys().forEach { playerId ->
            val playerEmbeddingsJson = root.getJSONArray(playerId)
            val playerEmbeddings = registry.getOrPut(playerId) { mutableListOf() }

            for (embeddingIndex in 0 until playerEmbeddingsJson.length()) {
                val embeddingJson = playerEmbeddingsJson.getJSONArray(embeddingIndex)
                playerEmbeddings += jsonArrayToFloatArray(embeddingJson)
            }
        }
    }

    /**
     * Exports one player's embeddings as a single-player registry JSON object.
     *
     * Returned format:
     * `{ "playerId": [[...], [...]] }`
     *
     * @param playerId Player to export.
     * @throws NoSuchElementException if the player is not registered.
     */
    fun exportEmbeddings(playerId: String): String {
        val playerEmbeddings = registry[playerId]
            ?: throw NoSuchElementException("Player '$playerId' not found.")

        return JSONObject()
            .put(playerId, embeddingsToJsonArray(playerEmbeddings))
            .toString()
    }

    /**
     * Exports the entire registry.
     *
     * Returned format:
     * `{ "playerId": [[...], [...]], "otherPlayer": [[...]] }`
     */
    fun exportAll(): String {
        val root = JSONObject()
        registry.forEach { (playerId, embeddings) ->
            root.put(playerId, embeddingsToJsonArray(embeddings))
        }

        return root.toString()
    }

    /**
     * Returns a read-only snapshot of the current registry contents.
     *
     * The returned map and lists are read-only views, but `FloatArray` values remain mutable
     * because arrays are mutable by nature.
     */
    fun getAll(): Map<String, List<FloatArray>> {
        return registry.mapValues { (_, embeddings) -> embeddings.toList() }
    }

    /** Clears all registered players and embeddings. */
    fun clear() {
        registry.clear()
    }

    /** @return Number of registered players currently stored in memory. */
    fun playerCount(): Int = registry.size

    /** Ensures the injected MediaPipe helpers are available before registration runs. */
    private fun checkDependencies() {
        check(::objectDetectorHelper.isInitialized) {
            "PlayerRegistry.objectDetectorHelper must be initialized before use."
        }
        check(::imageEmbedderHelper.isInitialized) {
            "PlayerRegistry.imageEmbedderHelper must be initialized before use."
        }
    }

    /** Converts a list of embeddings into the JSON array format used by the registry. */
    private fun embeddingsToJsonArray(embeddings: List<FloatArray>): JSONArray {
        val embeddingsJson = JSONArray()
        embeddings.forEach { embedding ->
            embeddingsJson.put(floatArrayToJsonArray(embedding))
        }
        return embeddingsJson
    }

    /** Converts a float array into a JSON array of numbers. */
    private fun floatArrayToJsonArray(values: FloatArray): JSONArray {
        val jsonArray = JSONArray()
        values.forEach { value ->
            jsonArray.put(value.toDouble())
        }
        return jsonArray
    }

    /** Converts a JSON numeric array into a float array. */
    private fun jsonArrayToFloatArray(jsonArray: JSONArray): FloatArray {
        return FloatArray(jsonArray.length()) { index ->
            jsonArray.getDouble(index).toFloat()
        }
    }

    /** Computes rectangle area for largest-box selection during registration. */
    private fun rectArea(rect: RectF): Float {
        return rect.width() * rect.height()
    }
}
