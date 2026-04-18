package com.example.triggerroyale

/**
 * Stored embedding bundle for one registered player.
 *
 * @param playerId Stable game-side identifier for the player.
 * @param embeddings All accepted embeddings collected for that player.
 */
data class PlayerEmbedding(
    val playerId: String,
    val embeddings: List<FloatArray>
)
