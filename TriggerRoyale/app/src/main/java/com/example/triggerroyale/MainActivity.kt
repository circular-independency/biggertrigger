package com.example.triggerroyale

import android.Manifest
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.os.Bundle
import android.util.Log
import android.widget.Toast
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import androidx.camera.core.CameraSelector
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.core.content.ContextCompat
import com.example.triggerroyale.databinding.ActivityMainBinding
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import java.io.File
import java.io.FileOutputStream

/**
 * Temporary native test harness for the Kotlin vision module.
 *
 * Responsibilities:
 * - request camera permission
 * - own CameraX preview setup
 * - grab the current preview frame when the player shoots
 * - run one-shot object detection on that frame
 * - extract a debug body crop for the selected target
 * - display debug detections over the preview
 *
 * The current implementation intentionally avoids continuously converting CameraX analysis frames
 * into `Bitmap`s. On some Mali devices that path can spam gralloc errors. Pulling a bitmap from
 * `PreviewView` on demand is simpler and keeps the whole current MVP in one coordinate space.
 */
class MainActivity : AppCompatActivity() {
    private lateinit var binding: ActivityMainBinding

    /** Coroutine scope for UI-triggered work tied to the activity lifetime. */
    private val activityScope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)

    /** MediaPipe detector helper. Created after camera permission is available. */
    private var objectDetectorHelper: ObjectDetectorHelper? = null

    /** MediaPipe image embedder helper. Created during activity startup. */
    private var imageEmbedderHelper: ImageEmbedderHelper? = null

    /** Holds the latest captured preview frame for the shoot pipeline. */
    private val frameHolder = FrameHolder()

    /** End-to-end shoot pipeline. Created once detector and embedder are both ready. */
    private var shootPipeline: ShootPipeline? = null

    /**
     * Permission launcher for camera access.
     *
     * When granted, both the detector and preview pipeline are initialized immediately.
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
        initializeImageEmbedder()

        binding.shootButton.setOnClickListener {
            val pipeline = shootPipeline
            if (pipeline == null) {
                Toast.makeText(this, "Shoot pipeline not ready", Toast.LENGTH_SHORT).show()
                return@setOnClickListener
            }

            frameHolder.setLatest(binding.previewView.bitmap)

            activityScope.launch {
                val result = pipeline.shoot()
                binding.detectionOverlay.setOverlayState(pipeline.lastMappedBoxes, result)

                when (result) {
                    ShootResult.Miss -> {
                        Log.d(TAG, "Shoot result: MISS")
                    }
                    ShootResult.Unknown -> {
                        Log.d(TAG, "Shoot result: UNKNOWN")
                    }
                    is ShootResult.Hit -> {
                        Log.d(
                            TAG,
                            "Shoot result: HIT ${result.playerId} confidence=${result.confidence}"
                        )
                    }
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

    /** Releases coroutine and detector resources when the activity goes away. */
    override fun onDestroy() {
        super.onDestroy()
        activityScope.cancel()
        objectDetectorHelper?.close()
        objectDetectorHelper = null
        imageEmbedderHelper?.close()
        imageEmbedderHelper = null
    }

    /** @return `true` when the app already has camera permission. */
    private fun hasCameraPermission(): Boolean {
        return ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.CAMERA
        ) == PackageManager.PERMISSION_GRANTED
    }

    /**
     * Binds the CameraX preview use case to the activity lifecycle.
     *
     * The current shoot pipeline reads pixels from `PreviewView.bitmap` on demand instead of from a
     * continuously running analysis stream.
     */
    private fun startCamera() {
        val cameraProviderFuture = ProcessCameraProvider.getInstance(this)

        cameraProviderFuture.addListener(
            {
                val cameraProvider = cameraProviderFuture.get()
                val preview = Preview.Builder().build().also { previewUseCase ->
                    previewUseCase.setSurfaceProvider(binding.previewView.surfaceProvider)
                }

                try {
                    cameraProvider.unbindAll()
                    cameraProvider.bindToLifecycle(
                        this,
                        CameraSelector.DEFAULT_BACK_CAMERA,
                        preview
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

        objectDetectorHelper?.let { helper ->
            PlayerRegistry.objectDetectorHelper = helper
            rebuildShootPipelineIfReady()
        }
    }

    /**
     * Creates the image embedder once for the activity lifetime.
     *
     * Failures are surfaced through logs and a toast so missing or incompatible model assets are
     * visible immediately during development.
     */
    private fun initializeImageEmbedder() {
        if (imageEmbedderHelper != null) {
            return
        }

        imageEmbedderHelper = try {
            ImageEmbedderHelper(this)
        } catch (exception: Exception) {
            Log.e(TAG, "Failed to initialize image embedder", exception)
            Toast.makeText(this, "Failed to initialize embedder", Toast.LENGTH_SHORT).show()
            null
        }

        imageEmbedderHelper?.let { helper ->
            PlayerRegistry.imageEmbedderHelper = helper
            rebuildShootPipelineIfReady()
        }
    }

    /**
     * Creates or refreshes the shoot pipeline once both MediaPipe helpers are available.
     */
    private fun rebuildShootPipelineIfReady() {
        val detector = objectDetectorHelper ?: return
        val embedder = imageEmbedderHelper ?: return

        shootPipeline = ShootPipeline(
            detectorHelper = detector,
            embedderHelper = embedder,
            frameHolder = frameHolder,
            previewWidth = { binding.previewView.width },
            previewHeight = { binding.previewView.height }
        )
    }

    companion object {
        /** Tag used for logcat output from this activity. */
        private const val TAG = "MainActivity"
    }
}
