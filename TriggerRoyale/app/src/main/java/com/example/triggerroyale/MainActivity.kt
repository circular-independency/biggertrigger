package com.example.triggerroyale

import android.Manifest
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.PointF
import android.graphics.RectF
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
import kotlinx.coroutines.withContext
import java.io.File
import java.io.FileOutputStream
import kotlin.math.hypot

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
            val detector = objectDetectorHelper
            if (detector == null) {
                Toast.makeText(this, "Detector not ready", Toast.LENGTH_SHORT).show()
                return@setOnClickListener
            }
            val embedder = imageEmbedderHelper
            if (embedder == null) {
                Toast.makeText(this, "Embedder not ready", Toast.LENGTH_SHORT).show()
                return@setOnClickListener
            }

            // Capture the frame exactly as the player sees it. This removes any need for image-to-
            // preview coordinate mapping in the current MVP and avoids the noisy ImageProxy path.
            val frame = binding.previewView.bitmap
            if (frame == null) {
                Toast.makeText(this, "No frame yet", Toast.LENGTH_SHORT).show()
                return@setOnClickListener
            }

            val imageCenter = PointF(frame.width / 2f, frame.height / 2f)

            activityScope.launch {
                // Run ML and crop work off the main thread to keep the UI responsive.
                val personBoxes = withContext(Dispatchers.Default) {
                    detector.detect(frame)
                }

                // The frame comes from PreviewView itself, so detector boxes are already in the
                // same coordinate space as the on-screen preview and crosshair.
                binding.detectionOverlay.setDetections(personBoxes)
                Log.d(TAG, "Detected persons: ${personBoxes.size}")

                if (personBoxes.isEmpty()) {
                    Toast.makeText(this@MainActivity, MISS_NO_PERSON_MESSAGE, Toast.LENGTH_SHORT)
                        .show()
                    return@launch
                }

                val hitBoxes = personBoxes.filter { imageBox ->
                    imageBox.contains(imageCenter.x, imageCenter.y)
                }

                if (hitBoxes.isEmpty()) {
                    Toast.makeText(this@MainActivity, MISS_MESSAGE, Toast.LENGTH_SHORT).show()
                    Log.d(TAG, "MISS \u2013 crosshair not inside any box")
                    return@launch
                }

                val chosenHitBox = hitBoxes.minByOrNull { hitBox ->
                    distanceBetweenCenters(hitBox, imageCenter)
                } ?: return@launch

                Log.d(TAG, "HIT \u2013 crosshair inside person box ${formatRect(chosenHitBox)}")

                val cropFile = withContext(Dispatchers.Default) {
                    val crop = CropHelper.cropPersonFromBitmap(frame, chosenHitBox)
                    val shouldRejectAsBlurry =
                        VisionConfig.enableBlurRejection &&
                            CropHelper.isBlurry(crop, VisionConfig.blurThreshold)


                    if (shouldRejectAsBlurry) {
                        null
                    } else {
                        saveDebugCrop(crop)
                    }
                }

                if (cropFile == null) {
                    Toast.makeText(this@MainActivity, UNKNOWN_BLURRY_MESSAGE, Toast.LENGTH_SHORT)
                        .show()
                    return@launch
                }

                Log.d(TAG, "Saved debug crop to ${cropFile.absolutePath}")

                val embedding = withContext(Dispatchers.Default) {
                    val crop = CropHelper.cropPersonFromBitmap(frame, chosenHitBox)
                    embedder.embed(crop)
                }

                Log.d(TAG, "Embedding size: ${embedding.size}")
                Toast.makeText(
                    this@MainActivity,
                    "Embedding OK \u2013 size ${embedding.size}",
                    Toast.LENGTH_SHORT
                ).show()
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
    }

    /**
     * Calculates the Euclidean distance between a box center and the crosshair center.
     *
     * When multiple person boxes overlap the crosshair, the closest center is treated as the
     * selected target.
     */
    private fun distanceBetweenCenters(box: RectF, point: PointF): Double {
        return hypot((box.centerX() - point.x).toDouble(), (box.centerY() - point.y).toDouble())
    }

    /**
     * Saves a cropped bitmap as a JPEG into the app-specific external files directory.
     *
     * This is only for debugging right now so developers can inspect the exact crop that would be
     * passed to future identification stages.
     */
    private fun saveDebugCrop(crop: Bitmap): File {
        val outputDirectory = getExternalFilesDir(null) ?: filesDir
        val outputFile = File(outputDirectory, "debug_crop_${System.currentTimeMillis()}.jpg")

        FileOutputStream(outputFile).use { outputStream ->
            crop.compress(Bitmap.CompressFormat.JPEG, DEBUG_CROP_JPEG_QUALITY, outputStream)
        }

        return outputFile
    }

    /**
     * Formats a rectangle for compact log output.
     *
     * Values are rounded to whole pixels to keep logcat easy to scan.
     */
    private fun formatRect(rect: RectF): String {
        return "[l=${rect.left.toInt()}, t=${rect.top.toInt()}, r=${rect.right.toInt()}, b=${rect.bottom.toInt()}]"
    }

    companion object {
        /** Tag used for logcat output from this activity. */
        private const val TAG = "MainActivity"

        /** Player-facing message used when people are detected but the crosshair misses all boxes. */
        private const val MISS_MESSAGE = "MISS"

        /** Player-facing message used when shoot finds no detected person. */
        private const val MISS_NO_PERSON_MESSAGE = "MISS \u2013 no person detected"

        /** Player-facing message used when a target crop is too blurry for later use. */
        private const val UNKNOWN_BLURRY_MESSAGE = "UNKNOWN \u2013 blurry frame"

        /** JPEG quality for saved debug crops. */
        private const val DEBUG_CROP_JPEG_QUALITY = 95
    }
}
