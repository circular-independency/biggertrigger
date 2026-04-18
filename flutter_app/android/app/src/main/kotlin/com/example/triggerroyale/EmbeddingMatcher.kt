package com.example.triggerroyale

/**
 * Compares a query embedding against the stored player registry.
 *
 * Embeddings are already L2-normalized by the image embedder configuration, so cosine similarity
 * can be computed as a plain dot product.
 */
object EmbeddingMatcher {
    /**
     * Finds the best-matching player in the registry.
     *
     * Each player's score is the maximum similarity across all stored embeddings for that player.
     * The overall best player is returned only if their score meets the provided threshold.
     *
     * @param queryEmbedding Query embedding to match.
     * @param registry Player registry keyed by player id.
     * @param threshold Minimum similarity required to accept a match.
     * @return `(playerId, score)` when a match is found, otherwise `null`.
     */
    fun findBestMatch(
        queryEmbedding: FloatArray,
        registry: Map<String, List<FloatArray>>,
        threshold: Float = 0.30f
    ): Pair<String, Float>? {
        var bestPlayerId: String? = null
        var bestScore = Float.NEGATIVE_INFINITY

        registry.forEach { (playerId, embeddings) ->
            val playerScore = embeddings.maxOfOrNull { storedEmbedding ->
                dotProduct(queryEmbedding, storedEmbedding)
            } ?: return@forEach

            if (playerScore > bestScore) {
                bestPlayerId = playerId
                bestScore = playerScore
            }
        }

        if (bestPlayerId == null || bestScore < threshold) {
            return null
        }

        return bestPlayerId!! to bestScore
    }

    /** Computes cosine similarity for two already-normalized embeddings. */
    private fun dotProduct(left: FloatArray, right: FloatArray): Float {
        if (left.size != right.size) {
            return Float.NEGATIVE_INFINITY
        }

        var sum = 0f
        for (index in left.indices) {
            sum += left[index] * right[index]
        }
        return sum
    }
}
