package com.athena.athena

import android.annotation.SuppressLint
import android.app.Activity
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.graphics.PixelFormat
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.Image
import android.media.ImageReader
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.DisplayMetrics
import android.view.Gravity
import android.view.WindowManager
import android.widget.Button
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.app.NotificationCompat
import java.nio.ByteBuffer

class FloatingOverlayService : Service() {

    private var windowManager: WindowManager? = null
    private var overlayView: FrameLayout? = null
    private var mediaProjection: MediaProjection? = null
    private var virtualDisplay: VirtualDisplay? = null
    private var imageReader: ImageReader? = null
    private var captureThread: Thread? = null
    private var isCapturing = false
    private var isPaused = false
    private val handler = Handler(Looper.getMainLooper())
    private var autoCloseRunnable: Runnable? = null
    private var maxDurationMs = 30000
    private val capturedFrames = mutableListOf<ByteArray>()
    private var captureStartTime = 0L
    private var scanButton: Button? = null
    private var pausePlayButton: Button? = null
    private var finishButton: Button? = null
    private var statusText: TextView? = null
    private var imageReceiver: ImageReader? = null

    private val frameBroadcastReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            when (intent?.action) {
                ACTION_SCAN -> startScanning()
                ACTION_PAUSE_PLAY -> togglePausePlay()
                ACTION_FINISH -> finishScanning()
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager

        val filter = IntentFilter().apply {
            addAction(ACTION_SCAN)
            addAction(ACTION_PAUSE_PLAY)
            addAction(ACTION_FINISH)
        }
        registerReceiver(frameBroadcastReceiver, filter)

        createNotificationChannel()
        startForeground(NOTIFICATION_ID, createNotification("Waiting for permission..."))
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        maxDurationMs = intent?.getIntExtra("maxDurationMs", 30000) ?: 30000
        val resultCode = intent?.getIntExtra("resultCode", Activity.RESULT_CANCELED)
        val data = intent?.getParcelableExtra<Intent>("data")

        if (resultCode == Activity.RESULT_OK && data != null) {
            val projectionManager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
            mediaProjection = projectionManager.getMediaProjection(resultCode, data)
            setupCapture()
            // Create overlay ONLY after we have a valid mediaProjection
            createOverlayView()
            updateNotification("Ready — tap SCAN to begin")
        } else {
            // No permission — still show overlay in demo/denied mode
            createOverlayView()
            updateNotification("Permission denied — demo mode")
        }

        return START_STICKY
    }

    private fun createOverlayView() {
        overlayView = FrameLayout(this)

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            else
                @Suppress("DEPRECATION")
                WindowManager.LayoutParams.TYPE_PHONE,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
            horizontalMargin = 24f
        }

        try {
            windowManager?.addView(overlayView, params)
        } catch (e: Exception) {
            // May fail on some devices without SYSTEM_ALERT_WINDOW permission
        }

        updateOverlayContent()
    }

    @SuppressLint("SetTextI18n")
    private fun updateOverlayContent() {
        val view = overlayView ?: return
        view.removeAllViews()

        val container = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(0xFF1A1A2E.toInt())
            setPadding(48, 32, 48, 32)
        }

        val row = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
        }

        statusText = TextView(this).apply {
            text = " Tap SCAN to start"
            setTextColor(0xFFFFFFFF.toInt())
            textSize = 14f
        }

        scanButton = Button(this).apply {
            text = "SCAN"
            setBackgroundColor(0xFF6366F1.toInt())
            setTextColor(0xFFFFFFFF.toInt())
            setOnClickListener { sendBroadcast(Intent(ACTION_SCAN)) }
        }

        pausePlayButton = Button(this).apply {
            text = "PAUSE"
            setBackgroundColor(0xFF8B5CF6.toInt())
            setTextColor(0xFFFFFFFF.toInt())
            isEnabled = false
            setOnClickListener { sendBroadcast(Intent(ACTION_PAUSE_PLAY)) }
        }

        finishButton = Button(this).apply {
            text = "FINISH"
            setBackgroundColor(0xFF10B981.toInt())
            setTextColor(0xFFFFFFFF.toInt())
            isEnabled = false
            setOnClickListener { sendBroadcast(Intent(ACTION_FINISH)) }
        }

        val btnParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
        btnParams.setMargins(8, 0, 8, 0)

        row.addView(scanButton, btnParams)
        row.addView(pausePlayButton, btnParams)
        row.addView(finishButton, btnParams)

        container.addView(statusText, LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        ).apply { bottomMargin = 24 })

        container.addView(row)

        view.addView(container)
    }

    @SuppressLint("WrongConstant")
    private fun setupCapture() {
        val metrics = DisplayMetrics()
        windowManager?.defaultDisplay?.getMetrics(metrics)
        val width = metrics.widthPixels
        val height = metrics.heightPixels
        val dpi = metrics.densityDpi

        imageReader = ImageReader.newInstance(width, height, PixelFormat.RGBA_8888, 2)
        // imageReceiver is the field used by the capture thread; keep in sync
        imageReceiver = imageReader

        mediaProjection?.registerCallback(object : MediaProjection.Callback() {
            override fun onStop() {
                stopCapture()
            }
        }, null)

        virtualDisplay = mediaProjection?.createVirtualDisplay(
            "AthenaCapture",
            width, height, dpi,
            DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR,
            imageReader?.surface, null, null
        )

        capturedFrames.clear()
        captureStartTime = System.currentTimeMillis()
    }

    private fun startScanning() {
        if (isCapturing) return
        if (imageReceiver == null) {
            statusText?.text = " Capture not ready, try again"
            return
        }
        isCapturing = true
        isPaused = false

        scanButton?.isEnabled = false
        pausePlayButton?.isEnabled = true
        finishButton?.isEnabled = true
        statusText?.text = " Scanning..."

        // Cancel any existing auto-close timer
        autoCloseRunnable?.let { handler.removeCallbacks(it) }
        // Auto-close timer starts from SCAN tap, not from service start
        autoCloseRunnable = Runnable {
            if (isCapturing) {
                finishScanning()
            }
        }
        handler.postDelayed(autoCloseRunnable!!, maxDurationMs.toLong())

        // Start frame capture thread
        captureThread = Thread {
            while (isCapturing) {
                if (!isPaused) {
                    val image = imageReceiver?.acquireLatestImage()
                    if (image != null) {
                        val frame = imageToBytes(image)
                        image.close()
                        if (frame != null) {
                            capturedFrames.add(frame)
                            broadcastFrame(frame)
                        }
                    }
                }
                try {
                    Thread.sleep(100)
                } catch (e: InterruptedException) {
                    break
                }
            }
        }
        captureThread?.start()

        updateNotification("Scanning in progress...")
    }

    private fun togglePausePlay() {
        isPaused = !isPaused
        pausePlayButton?.text = if (isPaused) "PLAY" else "PAUSE"
        statusText?.text = if (isPaused) " Paused" else " Scanning..."
    }

    private fun finishScanning() {
        isCapturing = false
        scanButton?.isEnabled = true
        pausePlayButton?.isEnabled = false
        finishButton?.isEnabled = false

        autoCloseRunnable?.let { handler.removeCallbacks(it) }

        val duration = System.currentTimeMillis() - captureStartTime
        statusText?.text = " Done! ${capturedFrames.size} frames"

        val intent = Intent("com.athena.app.SCAN_COMPLETE").apply {
            putExtra("frameCount", capturedFrames.size)
            putExtra("durationMs", duration.toInt())
        }
        sendBroadcast(intent)

        handler.postDelayed({
            stopSelf()
        }, 2000)
    }

    private fun stopCapture() {
        isCapturing = false
        isPaused = false
        captureThread?.interrupt()
        captureThread = null
        virtualDisplay?.release()
        imageReader?.close()
    }

    private fun imageToBytes(image: Image): ByteArray? {
        return try {
            val plane = image.planes[0]
            val buffer: ByteBuffer = plane.buffer
            val remaining = buffer.remaining()
            if (remaining == 0) return null
            val bytes = ByteArray(remaining)
            buffer.get(bytes)
            bytes
        } catch (e: Exception) {
            null
        }
    }

    private fun broadcastFrame(frame: ByteArray) {
        val intent = Intent("com.athena.app.FRAME_CAPTURED").apply {
            putExtra("frame_data", frame)
        }
        sendBroadcast(intent)
    }

    private fun createNotificationChannel() {
        val channel = NotificationChannel(
            CHANNEL_ID, "Athena Capture",
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "Screen capture notification"
        }
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(channel)
    }

    private fun createNotification(text: String): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Athena")
            .setContentText(text)
            .setSmallIcon(android.R.drawable.ic_menu_camera)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .build()
    }

    private fun updateNotification(text: String) {
        val manager = getSystemService(NotificationManager::class.java)
        manager.notify(NOTIFICATION_ID, createNotification(text))
    }

    override fun onDestroy() {
        super.onDestroy()
        autoCloseRunnable?.let { handler.removeCallbacks(it) }
        stopCapture()
        try {
            unregisterReceiver(frameBroadcastReceiver)
        } catch (_: Exception) {}
        overlayView?.let { windowManager?.removeView(it) }
        mediaProjection?.stop()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    companion object {
        const val CHANNEL_ID = "athena_capture_channel"
        const val NOTIFICATION_ID = 1
        const val ACTION_SCAN = "com.athena.app.ACTION_SCAN"
        const val ACTION_PAUSE_PLAY = "com.athena.app.ACTION_PAUSE_PLAY"
        const val ACTION_FINISH = "com.athena.app.ACTION_FINISH"
    }
}
