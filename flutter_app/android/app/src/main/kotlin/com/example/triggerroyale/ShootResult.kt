package com.example.triggerroyale

/**
 * Final outcome of a shoot attempt.
 */
sealed class ShootResult {
    /** No valid target was hit. */
    data object Miss : ShootResult()

    /** A target was seen but could not be confidently identified. */
    data object Unknown : ShootResult()

    /**
     * A registered player was matched successfully.
     *
     * @param playerId Matched player identifier.
     * @param confidence Cosine-similarity score for the winning match.
     */
    data class Hit(val playerId: String, val confidence: Float) : ShootResult()
}
