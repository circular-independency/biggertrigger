package com.example.triggerroyale

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.ImageFormat
import android.graphics.PointF
import android.graphics.RectF
import android.graphics.Rect
import android.graphics.YuvImage
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.ByteArrayOutputStream
import kotlin.math.hypot

/**
 * Flutter-facing plugin entrypoint for the native vision module.
 *
 * This plugin exposes:
 * - frame-based shoot pipeline
 * - player registration/import/export
 * - end-to-end `shoot()` identity matching
 */
class VisionFlutterPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private data class YuvFramePlane(
        val bytes: ByteArray,
        val rowStride: Int,
        val pixelStride: Int
    )

    private var applicationContext: Context? = null
    private var binaryMessenger: BinaryMessenger? = null
    private var methodChannel: MethodChannel? = null

    private val pluginScope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)

    private var objectDetectorHelper: ObjectDetectorHelper? = null
    private var imageEmbedderHelper: ImageEmbedderHelper? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = binding.applicationContext
        binaryMessenger = binding.binaryMessenger

        methodChannel = MethodChannel(
            binding.binaryMessenger,
            CHANNEL_NAME
        ).also { channel ->
            channel.setMethodCallHandler(this)
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "shootFrame" -> shootFrame(call, result)
            "registerPlayer" -> registerPlayer(call, result)
            "exportEmbeddings" -> exportEmbeddings(call, result)
            "exportAll" -> result.success(PlayerRegistry.exportAll())
            "importEmbeddings" -> importEmbeddings(call, result)
            "clearRegistrations" -> {
                PlayerRegistry.clear()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel?.setMethodCallHandler(null)
        pluginScope.cancel()
        objectDetectorHelper?.close()
        imageEmbedderHelper?.close()
        objectDetectorHelper = null
        imageEmbedderHelper = null
        applicationContext = null
        binaryMessenger = null
        methodChannel = null
    }

    /** Processes a Flutter camera frame and returns a shoot result map. */
    private fun shootFrame(call: MethodCall, result: MethodChannel.Result) {
        val initializationError = ensureVisionHelpers()
        if (initializationError != null) {
            result.error("SHOOT_FAILED", initializationError, null)
            return
        }

        val width = (call.argument<Number>("width"))?.toInt() ?: -1
        val height = (call.argument<Number>("height"))?.toInt() ?: -1
        val rawPlanes = call.argument<List<Any?>>("planes") ?: emptyList()

        if (width <= 0 || height <= 0 || rawPlanes.size < 3) {
            result.error("SHOOT_FAILED", "Invalid frame payload.", null)
            return
        }

        val planes = parsePlanes(rawPlanes)
        if (planes == null) {
            result.error("SHOOT_FAILED", "Invalid frame planes payload.", null)
            return
        }

        pluginScope.launch {
            try {
                val shootResult = withContext(Dispatchers.Default) {
                    val bitmap = decodeToUprightBitmap(
                        width = width,
                        height = height,
                        planes = planes
                    )
                    evaluateFrame(bitmap)
                }
                when (shootResult) {
                    ShootResult.Miss -> result.success(mapOf("result" to "MISS"))
                    ShootResult.Unknown -> result.success(mapOf("result" to "UNKNOWN"))
                    is ShootResult.Hit -> result.success(
                        mapOf(
                            "result" to "HIT",
                            "targetId" to shootResult.playerId,
                            "confidence" to shootResult.confidence.toDouble()
                        )
                    )
                }
            } catch (exception: Exception) {
                result.error("SHOOT_FAILED", exception.message, null)
            }
        }
    }

    /** Registers a player from JPEG-encoded bytes provided by Flutter. */
    private fun registerPlayer(call: MethodCall, result: MethodChannel.Result) {
        val initializationError = ensureVisionHelpers()
        if (initializationError != null) {
            result.error("REGISTRATION_FAILED", initializationError, null)
            return
        }

        val playerId = call.argument<String>("playerId")
        val imageBytes = (call.argument<List<Any?>>("imageBytes") ?: emptyList())
            .mapNotNull { item -> item as? ByteArray }

        if (playerId.isNullOrBlank() || imageBytes.isEmpty()) {
            result.error("REGISTRATION_FAILED", "Missing playerId or imageBytes.", null)
            return
        }

        pluginScope.launch {
            try {
                val playerEmbedding = withContext(Dispatchers.Default) {
                    val bitmaps = imageBytes.mapNotNull { bytes ->
                        BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
                    }
                    PlayerRegistry.register(playerId, bitmaps)
                }

                result.success(mapOf("storedCount" to playerEmbedding.embeddings.size))
            } catch (exception: IllegalArgumentException) {
                result.error("REGISTRATION_FAILED", exception.message, null)
            } catch (exception: Exception) {
                result.error("REGISTRATION_FAILED", exception.message, null)
            }
        }
    }

    /** Exports one player's embeddings as JSON. */
    private fun exportEmbeddings(call: MethodCall, result: MethodChannel.Result) {
        val playerId = call.argument<String>("playerId")
        if (playerId.isNullOrBlank()) {
            result.error("EXPORT_FAILED", "Missing playerId.", null)
            return
        }

        try {
            result.success(PlayerRegistry.exportEmbeddings(playerId))
        } catch (exception: NoSuchElementException) {
            result.error("EXPORT_FAILED", exception.message, null)
        }
    }

    /** Imports a registry JSON blob from Flutter. */
    private fun importEmbeddings(call: MethodCall, result: MethodChannel.Result) {
        val json = call.argument<String>("json")
        if (json == null) {
            result.error("IMPORT_FAILED", "Missing json.", null)
            return
        }

        try {
            PlayerRegistry.importEmbeddings(json)
            result.success(null)
        } catch (exception: Exception) {
            result.error("IMPORT_FAILED", exception.message, null)
        }
    }

    /**
     * Lazily initializes ML helpers so startup crashes are avoided when vision dependencies are not
     * available on the current device/runtime.
     *
     * @return null when initialization is successful, otherwise a user-facing error message.
     */
    private fun ensureVisionHelpers(): String? {
        val context = applicationContext ?: return "Plugin context is not available."
        var createdDetector = false
        var createdEmbedder = false

        try {
            if (objectDetectorHelper == null) {
                objectDetectorHelper = ObjectDetectorHelper(context)
                createdDetector = true
            }
            if (imageEmbedderHelper == null) {
                imageEmbedderHelper = ImageEmbedderHelper(context)
                createdEmbedder = true
            }

            val detector = objectDetectorHelper
            val embedder = imageEmbedderHelper
            if (detector == null || embedder == null) {
                return "Vision helpers are unavailable."
            }

            PlayerRegistry.objectDetectorHelper = detector
            PlayerRegistry.imageEmbedderHelper = embedder
            return null
        } catch (throwable: Throwable) {
            if (createdDetector) {
                try {
                    objectDetectorHelper?.close()
                } catch (_: Throwable) {
                    // Best-effort cleanup.
                }
                objectDetectorHelper = null
            }
            if (createdEmbedder) {
                try {
                    imageEmbedderHelper?.close()
                } catch (_: Throwable) {
                    // Best-effort cleanup.
                }
                imageEmbedderHelper = null
            }
            val message = throwable.message ?: throwable::class.java.simpleName
            return "Vision initialization failed: $message"
        }
    }

    private fun parsePlanes(rawPlanes: List<Any?>): List<YuvFramePlane>? {
        val planes = mutableListOf<YuvFramePlane>()
        for (rawPlane in rawPlanes.take(3)) {
            val map = rawPlane as? Map<*, *> ?: return null
            val bytes = map["bytes"] as? ByteArray ?: return null
            val rowStride = (map["bytesPerRow"] as? Number)?.toInt() ?: return null
            val pixelStride = (map["bytesPerPixel"] as? Number)?.toInt() ?: 1
            if (rowStride <= 0 || pixelStride <= 0) {
                return null
            }
            planes += YuvFramePlane(
                bytes = bytes,
                rowStride = rowStride,
                pixelStride = pixelStride
            )
        }
        return planes
    }

    private fun decodeToUprightBitmap(
        width: Int,
        height: Int,
        planes: List<YuvFramePlane>
    ): Bitmap {
        if (planes.size < 3) {
            throw IllegalArgumentException("YUV420_888 frame must include 3 planes.")
        }
        val nv21 = yuv420888ToNv21(
            width = width,
            height = height,
            yPlane = planes[0],
            uPlane = planes[1],
            vPlane = planes[2]
        )

        val jpegBytes = ByteArrayOutputStream().use { stream ->
            val yuvImage = YuvImage(nv21, ImageFormat.NV21, width, height, null)
            val ok = yuvImage.compressToJpeg(Rect(0, 0, width, height), 95, stream)
            if (!ok) {
                throw IllegalStateException("Failed to compress frame to JPEG.")
            }
            stream.toByteArray()
        }

        return BitmapFactory.decodeByteArray(jpegBytes, 0, jpegBytes.size)
            ?: throw IllegalStateException("Failed to decode frame bitmap.")
    }

    private fun yuv420888ToNv21(
        width: Int,
        height: Int,
        yPlane: YuvFramePlane,
        uPlane: YuvFramePlane,
        vPlane: YuvFramePlane
    ): ByteArray {
        val frameSize = width * height
        val nv21 = ByteArray(frameSize + frameSize / 2)

        var yOffset = 0
        for (row in 0 until height) {
            val rowStart = row * yPlane.rowStride
            for (col in 0 until width) {
                val index = rowStart + col * yPlane.pixelStride
                nv21[yOffset++] = byteAt(yPlane.bytes, index)
            }
        }

        val chromaWidth = width / 2
        val chromaHeight = height / 2
        var chromaOffset = frameSize
        for (row in 0 until chromaHeight) {
            val uRowStart = row * uPlane.rowStride
            val vRowStart = row * vPlane.rowStride
            for (col in 0 until chromaWidth) {
                val uIndex = uRowStart + col * uPlane.pixelStride
                val vIndex = vRowStart + col * vPlane.pixelStride
                nv21[chromaOffset++] = byteAt(vPlane.bytes, vIndex)
                nv21[chromaOffset++] = byteAt(uPlane.bytes, uIndex)
            }
        }

        return nv21
    }

    private fun evaluateFrame(bitmap: Bitmap): ShootResult {
        val detector = objectDetectorHelper ?: return ShootResult.Unknown
        val embedder = imageEmbedderHelper ?: return ShootResult.Unknown

        val imageBoxes = detector.detect(bitmap)
        if (imageBoxes.isEmpty()) {
            return ShootResult.Miss
        }

        val crosshairCenter = PointF(bitmap.width / 2f, bitmap.height / 2f)
        val crosshairRadius = VisionConfig.crosshairRadiusPx
        val crosshairCandidates = imageBoxes.filter { box ->
            box.contains(crosshairCenter.x, crosshairCenter.y) ||
                distanceBetweenCenters(box, crosshairCenter) <= crosshairRadius
        }

        if (crosshairCandidates.isEmpty()) {
            return ShootResult.Miss
        }

        val selectedBox = crosshairCandidates.minByOrNull { box ->
            distanceBetweenCenters(box, crosshairCenter)
        } ?: return ShootResult.Miss

        val crop = CropHelper.cropPersonFromBitmap(bitmap, selectedBox)
        if (VisionConfig.enableBlurRejection &&
            CropHelper.isBlurry(crop, VisionConfig.blurThreshold)
        ) {
            return ShootResult.Unknown
        }

        val embedding = try {
            embedder.embed(crop)
        } catch (_: Exception) {
            return ShootResult.Unknown
        }

        if (PlayerRegistry.playerCount() == 0) {
            return ShootResult.Unknown
        }

        val match = EmbeddingMatcher.findBestMatch(
            queryEmbedding = embedding,
            registry = PlayerRegistry.getAll(),
            threshold = VisionConfig.matchThreshold
        )
        return if (match != null) {
            ShootResult.Hit(match.first, match.second)
        } else {
            ShootResult.Unknown
        }
    }

    private fun distanceBetweenCenters(box: RectF, point: PointF): Double {
        return hypot((box.centerX() - point.x).toDouble(), (box.centerY() - point.y).toDouble())
    }

    private fun byteAt(bytes: ByteArray, index: Int): Byte {
        if (index < 0 || index >= bytes.size) {
            return 0
        }
        return bytes[index]
    }

    private companion object {
        private const val CHANNEL_NAME = "com.yourteam.visionmodule/vision"

        /**
         * Convenience self-registration hook for Flutter host apps that want an explicit call site.
         */
        @JvmStatic
        fun registerWith(flutterEngine: FlutterEngine) {
            flutterEngine.plugins.add(VisionFlutterPlugin())
        }
    }
}
