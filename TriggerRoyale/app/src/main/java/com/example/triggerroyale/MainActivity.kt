package com.example.triggerroyale

import android.Manifest
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Matrix
import android.os.Bundle
import android.util.Log
import android.widget.Toast
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.Preview
import androidx.camera.core.resolutionselector.ResolutionSelector
import androidx.camera.core.resolutionselector.ResolutionStrategy
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.core.content.ContextCompat
import com.example.triggerroyale.databinding.ActivityMainBinding
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicReference

/**
 * Temporary native test harness for the Kotlin vision module.
 *
 * Responsibilities:
 * - request camera permission
 * - own CameraX preview + analysis setup
 * - cache the latest upright analysis frame
 * - run one-shot object detection when the shoot button is pressed
 * - display debug detections over the preview
 *
 * This activity is intentionally small and procedural because it is standing in for the future
 * Flutter plugin boundary. Later, the same responsibilities can move behind plugin APIs.
 */
class MainActivity : AppCompatActivity() {
    private lateinit var binding: ActivityMainBinding

    /** Single-thread executor used by CameraX for bitmap extraction from analysis frames. */
    private val analysisExecutor = Executors.newSingleThreadExecutor()

    /**
     * Latest upright frame produced by the analysis pipeline.
     *
     * An [AtomicReference] is used because CameraX updates this on a background thread while the
     * shoot button reads it on the main thread.
     */
    private val latestFrame = AtomicReference<Bitmap?>(null)

    /** Coroutine scope for UI-triggered work tied to the activity lifetime. */
    private val activityScope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)

    /** MediaPipe detector helper. Created after camera permission is available. */
    private var objectDetectorHelper: ObjectDetectorHelper? = null

    /**
     * Permission launcher for camera access.
     *
     * When granted, both the detector and camera pipeline are initialized immediately.
     */
    private val cameraPermissionLauncher =
        registerForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
            if (granted) {
                initializeObjectDetector()
                startCamera()
            } else {
                Toast.makeText(this, "Camera permission denied", Toast.LENGTH_SHORT).show()
                finish()
            }
        }

    /** Sets up the UI and starts the native vision pipeline when permission is available. */
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityMainBinding.inflate(layoutInflater)
        setContentView(binding.root)

        binding.shootButton.setOnClickListener {
            // Read the most recent cached analysis frame. The camera pipeline updates this
            // continuously in the background, and shoot() consumes the latest available result.
            val frame = latestFrame.get()
            if (frame == null) {
                Toast.makeText(this, "No frame yet", Toast.LENGTH_SHORT).show()
                return@setOnClickListener
            }

            val detector = objectDetectorHelper
            if (detector == null) {
                Toast.makeText(this, "Detector not ready", Toast.LENGTH_SHORT).show()
                return@setOnClickListener
            }

            activityScope.launch {
                // Run ML work off the main thread to keep the UI responsive.
                val personBoxes = withContext(Dispatchers.Default) {
                    detector.detect(frame)
                }

                // Draw the detections back on the main thread because this updates the view.
                binding.detectionOverlay.setDetections(frame.width, frame.height, personBoxes)
                Log.d(TAG, "Detected persons: ${personBoxes.size}")

                if (personBoxes.isEmpty()) {
                    Toast.makeText(this@MainActivity, MISS_NO_PERSON_MESSAGE, Toast.LENGTH_SHORT)
                        .show()
                }
            }
        }

        if (hasCameraPermission()) {
            initializeObjectDetector()
            startCamera()
        } else {
            cameraPermissionLauncher.launch(Manifest.permission.CAMERA)
        }
    }

    /** Releases executor, coroutine, bitmap, and detector resources when the activity goes away. */
    override fun onDestroy() {
        super.onDestroy()
        activityScope.cancel()
        analysisExecutor.shutdown()
        latestFrame.set(null)
        objectDetectorHelper?.close()
        objectDetectorHelper = null
    }

    /** @return `true` when the app already has camera permission. */
    private fun hasCameraPermission(): Boolean {
        return ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.CAMERA
        ) == PackageManager.PERMISSION_GRANTED
    }

    /**
     * Binds CameraX preview and analysis use cases to the activity lifecycle.
     *
     * Preview is shown to the player, while analysis continuously updates [latestFrame].
     */
    private fun startCamera() {
        val cameraProviderFuture = ProcessCameraProvider.getInstance(this)

        cameraProviderFuture.addListener(
            {
                val cameraProvider = cameraProviderFuture.get()

                // Preview drives the on-screen camera feed.
                val preview = Preview.Builder().build().also { previewUseCase ->
                    previewUseCase.setSurfaceProvider(binding.previewView.surfaceProvider)
                }

                // Analysis produces smaller, ML-friendly frames independent from preview rendering.
                val imageAnalysis = buildImageAnalysis()

                try {
                    cameraProvider.unbindAll()
                    cameraProvider.bindToLifecycle(
                        this,
                        CameraSelector.DEFAULT_BACK_CAMERA,
                        preview,
                        imageAnalysis
                    )
                } catch (exception: Exception) {
                    Log.e(TAG, "Failed to bind camera preview", exception)
                    Toast.makeText(this, "Failed to start camera preview", Toast.LENGTH_SHORT)
                        .show()
                    finish()
                }
            },
            ContextCompat.getMainExecutor(this)
        )
    }

    /**
     * Creates the CameraX analysis use case used by the vision pipeline.
     *
     * Configuration choices:
     * - resolution comes from [VisionConfig.analysisResolution]
     * - keep-only-latest avoids backlog if analysis falls behind
     * - RGBA output allows direct conversion to a Bitmap
     */
    private fun buildImageAnalysis(): ImageAnalysis {
        val resolutionSelector = ResolutionSelector.Builder()
            .setResolutionStrategy(
                ResolutionStrategy(
                    VisionConfig.analysisResolution,
                    ResolutionStrategy.FALLBACK_RULE_CLOSEST_HIGHER_THEN_LOWER
                )
            )
            .build()

        return ImageAnalysis.Builder()
            .setResolutionSelector(resolutionSelector)
            .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
            .setOutputImageFormat(ImageAnalysis.OUTPUT_IMAGE_FORMAT_RGBA_8888)
            .build()
            .also { analysisUseCase ->
                analysisUseCase.setAnalyzer(analysisExecutor) { imageProxy ->
                    // Convert immediately, then close the proxy immediately. Holding the proxy open
                    // would stall CameraX frame delivery.
                    val bitmap = imageProxy.toBitmap()
                    val rotationDegrees = imageProxy.imageInfo.rotationDegrees
                    imageProxy.close()

                    // Store a consistently upright bitmap so downstream ML and UI code do not need
                    // to reason about camera sensor rotation on every read.
                    latestFrame.set(rotateBitmap(bitmap, rotationDegrees))
                }
            }
    }

    /**
     * Rotates a bitmap into upright display orientation.
     *
     * @param bitmap Source bitmap produced by CameraX.
     * @param rotationDegrees Rotation reported by CameraX for this frame.
     * @return The original bitmap when no rotation is needed, otherwise a rotated copy.
     */
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

    /**
     * Creates the object detector once for the activity lifetime.
     *
     * Failures are surfaced through logs and a toast so development issues such as model loading
     * problems are visible immediately.
     */
    private fun initializeObjectDetector() {
        if (objectDetectorHelper != null) {
            return
        }

        objectDetectorHelper = try {
            ObjectDetectorHelper(this)
        } catch (exception: Exception) {
            Log.e(TAG, "Failed to initialize object detector", exception)
            Toast.makeText(this, "Failed to initialize detector", Toast.LENGTH_SHORT).show()
            null
        }
    }

    companion object {
        /** Tag used for logcat output from this activity. */
        private const val TAG = "MainActivity"

        /** Player-facing message used when shoot finds no detected person. */
        private const val MISS_NO_PERSON_MESSAGE = "MISS \u2013 no person detected"
    }
}
