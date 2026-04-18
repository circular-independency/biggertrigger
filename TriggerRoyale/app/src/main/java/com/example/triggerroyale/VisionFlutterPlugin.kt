package com.example.triggerroyale

// Dart side usage:
//
// final _channel = MethodChannel('com.yourteam.visionmodule/vision');
//
// final int textureId = await _channel.invokeMethod('startPreview');
// // render with: Texture(textureId: textureId)
//
// await _channel.invokeMethod('registerPlayer', {
//   'playerId': 'alice',
//   'imageBytes': [jpegBytes1, jpegBytes2, ...]  // Uint8List from Flutter camera
// });
//
// final String json = await _channel.invokeMethod('exportEmbeddings', {'playerId': 'alice'});
// // send json to other players, then:
// await _channel.invokeMethod('importEmbeddings', {'json': receivedJson});
//
// final Map result = await _channel.invokeMethod('shoot');
// // result['result'] == 'MISS' | 'UNKNOWN' | 'HIT'
// // result['targetId'], result['confidence'] present on HIT

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.view.Surface
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.Preview
import androidx.camera.core.resolutionselector.ResolutionSelector
import androidx.camera.core.resolutionselector.ResolutionStrategy
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.lifecycle.LifecycleOwner
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.TextureRegistry
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * Flutter-facing plugin entrypoint for the native vision module.
 *
 * This plugin exposes:
 * - Texture-based camera preview
 * - player registration/import/export
 * - end-to-end `shoot()` identity matching
 */
class VisionFlutterPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private var applicationContext: Context? = null
    private var textureRegistry: TextureRegistry? = null
    private var binaryMessenger: BinaryMessenger? = null
    private var methodChannel: MethodChannel? = null

    private val pluginScope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private val cameraExecutor: ExecutorService = Executors.newSingleThreadExecutor()
    private val analysisExecutor: ExecutorService = Executors.newSingleThreadExecutor()

    private var objectDetectorHelper: ObjectDetectorHelper? = null
    private var imageEmbedderHelper: ImageEmbedderHelper? = null
    private val frameHolder = FrameHolder()
    private var shootPipeline: ShootPipeline? = null

    private var cameraProvider: ProcessCameraProvider? = null
    private var previewUseCase: Preview? = null
    private var imageAnalysisUseCase: ImageAnalysis? = null
    private var surfaceTextureEntry: TextureRegistry.SurfaceTextureEntry? = null
    private var previewSurface: Surface? = null
    private var previewBufferWidth = 0
    private var previewBufferHeight = 0

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = binding.applicationContext
        textureRegistry = binding.textureRegistry
        binaryMessenger = binding.binaryMessenger

        methodChannel = MethodChannel(
            binding.binaryMessenger,
            CHANNEL_NAME
        ).also { channel ->
            channel.setMethodCallHandler(this)
        }

        objectDetectorHelper = ObjectDetectorHelper(binding.applicationContext).also { helper ->
            PlayerRegistry.objectDetectorHelper = helper
        }
        imageEmbedderHelper = ImageEmbedderHelper(binding.applicationContext).also { helper ->
            PlayerRegistry.imageEmbedderHelper = helper
        }

        rebuildShootPipelineIfReady()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startPreview" -> startPreview(result)
            "stopPreview" -> stopPreview(result)
            "registerPlayer" -> registerPlayer(call, result)
            "exportEmbeddings" -> exportEmbeddings(call, result)
            "exportAll" -> result.success(PlayerRegistry.exportAll())
            "importEmbeddings" -> importEmbeddings(call, result)
            "shoot" -> shoot(result)
            "clearRegistrations" -> {
                PlayerRegistry.clear()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel?.setMethodCallHandler(null)
        stopPreviewInternal()
        pluginScope.cancel()
        cameraExecutor.shutdown()
        analysisExecutor.shutdown()
        objectDetectorHelper?.close()
        imageEmbedderHelper?.close()
        objectDetectorHelper = null
        imageEmbedderHelper = null
        shootPipeline = null
        applicationContext = null
        textureRegistry = null
        binaryMessenger = null
        methodChannel = null
    }

    /** Starts CameraX preview bound to a Flutter texture and returns the texture id. */
    private fun startPreview(result: MethodChannel.Result) {
        val context = applicationContext
        val registry = textureRegistry
        val detector = objectDetectorHelper
        val embedder = imageEmbedderHelper
        if (context == null || registry == null || detector == null || embedder == null) {
            result.error("PREVIEW_FAILED", "Plugin is not fully initialized.", null)
            return
        }

        pluginScope.launch {
            try {
                stopPreviewInternal()

                val textureEntry = registry.createSurfaceTexture()
                surfaceTextureEntry = textureEntry
                val provider = withContext(Dispatchers.Default) {
                    ProcessCameraProvider.getInstance(context).get()
                }
                cameraProvider = provider

                val lifecycleOwner = (context as? LifecycleOwner) ?: AppLifecycleOwner

                previewUseCase = Preview.Builder()
                    .build()
                    .also { preview ->
                        preview.setSurfaceProvider { request ->
                            previewBufferWidth = request.resolution.width
                            previewBufferHeight = request.resolution.height
                            textureEntry.surfaceTexture().setDefaultBufferSize(
                                previewBufferWidth,
                                previewBufferHeight
                            )

                            val surface = Surface(textureEntry.surfaceTexture())
                            previewSurface = surface
                            request.provideSurface(surface, cameraExecutor) { }
                        }
                    }

                imageAnalysisUseCase = ImageAnalysis.Builder()
                    .setResolutionSelector(
                        ResolutionSelector.Builder()
                            .setResolutionStrategy(
                                ResolutionStrategy(
                                    android.util.Size(
                                        VisionConfig.analysisWidth,
                                        VisionConfig.analysisHeight
                                    ),
                                    ResolutionStrategy.FALLBACK_RULE_CLOSEST_HIGHER_THEN_LOWER
                                )
                            )
                            .build()
                    )
                    .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                    .setOutputImageFormat(ImageAnalysis.OUTPUT_IMAGE_FORMAT_RGBA_8888)
                    .build()
                    .also { analysis ->
                        analysis.setAnalyzer(analysisExecutor) { imageProxy ->
                            val bitmap = imageProxy.toBitmap()
                            val rotationDegrees = imageProxy.imageInfo.rotationDegrees
                            imageProxy.close()

                            frameHolder.setLatest(rotateBitmap(bitmap, rotationDegrees))
                        }
                    }

                provider.unbindAll()
                provider.bindToLifecycle(
                    lifecycleOwner,
                    CameraSelector.DEFAULT_BACK_CAMERA,
                    previewUseCase,
                    imageAnalysisUseCase
                )

                shootPipeline = ShootPipeline(
                    detectorHelper = detector,
                    embedderHelper = embedder,
                    frameHolder = frameHolder,
                    previewWidth = {
                        if (previewBufferWidth > 0) previewBufferWidth
                        else frameHolder.getLatest()?.width ?: 0
                    },
                    previewHeight = {
                        if (previewBufferHeight > 0) previewBufferHeight
                        else frameHolder.getLatest()?.height ?: 0
                    }
                )

                result.success(textureEntry.id())
            } catch (exception: Exception) {
                stopPreviewInternal()
                result.error("PREVIEW_FAILED", exception.message, null)
            }
        }
    }

    /** Stops CameraX preview and releases the Flutter texture. */
    private fun stopPreview(result: MethodChannel.Result) {
        stopPreviewInternal()
        result.success(null)
    }

    /** Registers a player from JPEG-encoded bytes provided by Flutter. */
    private fun registerPlayer(call: MethodCall, result: MethodChannel.Result) {
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

    /** Runs the full shoot pipeline and returns a simple Flutter-friendly result map. */
    private fun shoot(result: MethodChannel.Result) {
        val pipeline = shootPipeline
        if (pipeline == null) {
            result.error("SHOOT_FAILED", "Shoot pipeline not ready.", null)
            return
        }

        pluginScope.launch {
            try {
                when (val shootResult = pipeline.shoot()) {
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

    /** Rebuilds the shoot pipeline once both helpers are available. */
    private fun rebuildShootPipelineIfReady() {
        val detector = objectDetectorHelper ?: return
        val embedder = imageEmbedderHelper ?: return

        shootPipeline = ShootPipeline(
            detectorHelper = detector,
            embedderHelper = embedder,
            frameHolder = frameHolder,
            previewWidth = {
                if (previewBufferWidth > 0) previewBufferWidth
                else frameHolder.getLatest()?.width ?: 0
            },
            previewHeight = {
                if (previewBufferHeight > 0) previewBufferHeight
                else frameHolder.getLatest()?.height ?: 0
            }
        )
    }

    /** Stops and releases all preview-related resources without touching the method result. */
    private fun stopPreviewInternal() {
        cameraProvider?.unbindAll()
        imageAnalysisUseCase = null
        previewUseCase = null
        previewSurface?.release()
        previewSurface = null
        surfaceTextureEntry?.release()
        surfaceTextureEntry = null
        previewBufferWidth = 0
        previewBufferHeight = 0
        frameHolder.setLatest(null)
        rebuildShootPipelineIfReady()
    }

    /** Rotates an analyzed frame into upright orientation before storing it in `FrameHolder`. */
    private fun rotateBitmap(bitmap: Bitmap, rotationDegrees: Int): Bitmap {
        if (rotationDegrees == 0) {
            return bitmap
        }

        val matrix = Matrix().apply {
            postRotate(rotationDegrees.toFloat())
        }

        return Bitmap.createBitmap(
            bitmap,
            0,
            0,
            bitmap.width,
            bitmap.height,
            matrix,
            true
        )
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
