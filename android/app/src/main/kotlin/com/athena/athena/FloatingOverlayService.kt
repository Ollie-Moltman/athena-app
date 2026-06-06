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
import android.widget.FrameLayout
import android.widget.ImageView
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
    private var elapsedSeconds = 0
    private var timerRunnable: Runnable? = null

    // UI refs
    private var scanBtn: ImageView? = null
    private var pausePlayBtn: ImageView? = null
    private var scanBtnWrapper: FrameLayout? = null
    private var pauseBtnWrapper: FrameLayout? = null
    private var cancelBtnWrapper: FrameLayout? = null
    private var timerText: TextView? = null
    private var statusText: TextView? = null
    private var recDot: TextView? = null
    private var scanLabel: TextView? = null
    private var pauseLabel: TextView? = null
    private var cancelLabel: TextView? = null
    // Text labels below buttons
    private var scanTextLabel: TextView? = null
    private var pauseTextLabel: TextView? = null
    private var cancelTextLabel: TextView? = null

    private val frameBroadcastReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            when (intent?.action) {
                ACTION_SCAN -> startScanning()
                ACTION_PAUSE_PLAY -> togglePausePlay()
                ACTION_FINISH -> if (isCapturing) finishScanning() else startScanning()
                ACTION_CANCEL -> cancelScanning()
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
            addAction(ACTION_CANCEL)
        }
        registerReceiver(frameBroadcastReceiver, filter)

        createNotificationChannel()
        startForeground(NOTIFICATION_ID, createNotification("Starting Athena..."))
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        maxDurationMs = intent?.getIntExtra("maxDurationMs", 30000) ?: 30000
        val resultCode = intent?.getIntExtra("resultCode", Activity.RESULT_CANCELED)
        val data = intent?.getParcelableExtra<Intent>("data")

        if (resultCode == Activity.RESULT_OK && data != null) {
            val projectionManager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
            mediaProjection = projectionManager.getMediaProjection(resultCode, data)
            // Create overlay immediately — user taps SCAN to begin actual capture
            createOverlayView()
            updateNotification("Ready — tap SCAN to begin")
        } else {
            createOverlayView()
            updateNotification("Permission denied")
        }

        return START_STICKY
    }

    @SuppressLint("WrongConstant", "SetTextI18n")
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
            WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                    WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.BOTTOM or Gravity.CENTER_HORIZONTAL
        }

        try {
            windowManager?.addView(overlayView, params)
        } catch (e: Exception) {
            try {
                android.widget.Toast.makeText(
                    this,
                    "Overlay failed: ${e.message}. Check Settings > Apps > Athena > Display over other apps.",
                    android.widget.Toast.LENGTH_LONG
                ).show()
            } catch (_: Exception) {}
            return
        }

        // Main container — solid dark background, clearly visible
        val container = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(0xFF1A1A2E.toInt())  // Solid dark, no transparency
            setPadding(24, 20, 24, 20)
        }

        // Debug banner at top — confirms overlay is created
        val debugBanner = TextView(this).apply {
            text = "ATHENA SCANNER"
            setTextColor(0xFF6366F1.toInt())
            textSize = 10f
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, 12)
        }

        // Top row: rec dot + status + timer
        val topRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(0, 0, 0, 16)
        }

        recDot = TextView(this).apply {
            text = "●"
            setTextColor(0xFFF85149.toInt())
            textSize = 18f
            setPadding(0, 0, 10, 0)
        }

        statusText = TextView(this).apply {
            text = "Ready — tap START"
            setTextColor(0xFFFFFFFF.toInt())
            textSize = 15f
        }

        timerText = TextView(this).apply {
            text = "0:00"
            setTextColor(0xFFAAAAAA.toInt())
            textSize = 15f
            setPadding(20, 0, 0, 0)
        }

        topRow.addView(recDot)
        topRow.addView(statusText)
        topRow.addView(timerText)

        // Button row — LARGE circular buttons (96dp) with text labels below
        val btnRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_HORIZONTAL
        }

        // START / FINISH button — big red circle (88dp)
        scanBtnWrapper = FrameLayout(this)
        scanBtnWrapper?.layoutParams = LinearLayout.LayoutParams(96, 96).apply { marginEnd = 24 }
        scanBtn = ImageView(this).apply {
            setBackgroundColor(0xFFF85149.toInt())
            alpha = 1f
        }
        scanLabel = TextView(this).apply {
            text = "⏺"
            setTextColor(0xFFFFFFFF.toInt())
            textSize = 40f
            gravity = Gravity.CENTER
        }
        scanBtnWrapper?.addView(scanBtn, FrameLayout.LayoutParams(88, 88).apply { gravity = Gravity.CENTER })
        scanBtnWrapper?.addView(scanLabel, FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT).apply { gravity = Gravity.CENTER })
        scanBtnWrapper?.setOnClickListener {
            statusText?.text = "START pressed!"
            sendBroadcast(Intent(ACTION_SCAN))
        }
        scanTextLabel = TextView(this).apply {
            text = "START"
            setTextColor(0xFFF85149.toInt())
            textSize = 12f
            gravity = Gravity.CENTER
            setPadding(0, 6, 0, 0)
        }

        // PAUSE / RESUME button — purple circle (68dp)
        pauseBtnWrapper = FrameLayout(this)
        pauseBtnWrapper?.layoutParams = LinearLayout.LayoutParams(80, 80).apply { marginEnd = 24 }
        pausePlayBtn = ImageView(this).apply {
            setBackgroundColor(0xFF8B5CF6.toInt())
            alpha = 0.4f
        }
        pauseLabel = TextView(this).apply {
            text = "⏸"
            setTextColor(0xFFFFFFFF.toInt())
            textSize = 30f
            gravity = Gravity.CENTER
        }
        pauseBtnWrapper?.addView(pausePlayBtn, FrameLayout.LayoutParams(68, 68).apply { gravity = Gravity.CENTER })
        pauseBtnWrapper?.addView(pauseLabel, FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT).apply { gravity = Gravity.CENTER })
        pauseBtnWrapper?.setOnClickListener {
            statusText?.text = "PAUSE pressed!"
            sendBroadcast(Intent(ACTION_PAUSE_PLAY))
        }
        pauseTextLabel = TextView(this).apply {
            text = "PAUSE"
            setTextColor(0xFF8B5CF6.toInt())
            textSize = 12f
            gravity = Gravity.CENTER
            setPadding(0, 6, 0, 0)
        }

        // CANCEL button — green circle (68dp)
        cancelBtnWrapper = FrameLayout(this)
        cancelBtnWrapper?.layoutParams = LinearLayout.LayoutParams(80, 80)
        val cancelBtnBg = ImageView(this).apply {
            setBackgroundColor(0xFF10B981.toInt())
            alpha = 0.4f
        }
        cancelLabel = TextView(this).apply {
            text = "✕"
            setTextColor(0xFFFFFFFF.toInt())
            textSize = 30f
            gravity = Gravity.CENTER
        }
        cancelBtnWrapper?.addView(cancelBtnBg, FrameLayout.LayoutParams(68, 68).apply { gravity = Gravity.CENTER })
        cancelBtnWrapper?.addView(cancelLabel, FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT).apply { gravity = Gravity.CENTER })
        cancelBtnWrapper?.setOnClickListener {
            statusText?.text = "CANCEL pressed!"
            sendBroadcast(Intent(ACTION_CANCEL))
        }
        cancelTextLabel = TextView(this).apply {
            text = "CANCEL"
            setTextColor(0xFF10B981.toInt())
            textSize = 12f
            gravity = Gravity.CENTER
            setPadding(0, 6, 0, 0)
        }

        // Wrap each button+label in a vertical LinearLayout
        fun buttonWithLabel(wrapper: FrameLayout, label: TextView): LinearLayout {
            return LinearLayout(this).apply {
                orientation = LinearLayout.VERTICAL
                gravity = Gravity.CENTER_HORIZONTAL
                addView(wrapper)
                addView(label)
            }
        }

        btnRow.addView(buttonWithLabel(scanBtnWrapper!!, scanTextLabel!!))
        btnRow.addView(buttonWithLabel(pauseBtnWrapper!!, pauseTextLabel!!))
        btnRow.addView(buttonWithLabel(cancelBtnWrapper!!, cancelTextLabel!!))

        container.addView(debugBanner)
        container.addView(topRow)
        container.addView(btnRow)

        overlayView!!.addView(container)
    }

    @SuppressLint("WrongConstant")
    private fun setupCapture() {
        val metrics = DisplayMetrics()
        windowManager?.defaultDisplay?.getMetrics(metrics)
        val width = metrics.widthPixels
        val height = metrics.heightPixels
        val dpi = metrics.densityDpi

        imageReader = ImageReader.newInstance(width, height, PixelFormat.RGBA_8888, 2)

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
        elapsedSeconds = 0
    }

    private fun startScanning() {
        if (isCapturing) return

        // Guard: need mediaProjection to capture
        if (mediaProjection == null) {
            statusText?.text = "Permission needed"
            try {
                android.widget.Toast.makeText(
                    this,
                    "Screen capture permission required. Please try again.",
                    android.widget.Toast.LENGTH_SHORT
                ).show()
            } catch (_: Exception) {}
            return
        }

        // Set up MediaProjection + ImageReader if not already done
        if (imageReader == null) {
            setupCapture()
        }

        isCapturing = true
        isPaused = false

        // Update UI: scan button shows ⏹ (finish), pause/cancel become active
        scanBtn?.alpha = 1f
        scanLabel?.text = "⏹"
        scanTextLabel?.text = "FINISH"
        scanBtnWrapper?.isEnabled = true
        pausePlayBtn?.alpha = 1f
        pauseBtnWrapper?.isEnabled = true
        pauseLabel?.text = "⏸"
        pauseTextLabel?.text = "PAUSE"
        cancelBtnWrapper?.alpha = 1f
        cancelBtnWrapper?.isEnabled = true
        statusText?.text = "Recording"
        recDot?.setTextColor(0xFFF85149.toInt())

        // Cancel any existing auto-close timer
        autoCloseRunnable?.let { handler.removeCallbacks(it) }
        autoCloseRunnable = Runnable {
            if (isCapturing) {
                finishScanning()
            }
        }
        handler.postDelayed(autoCloseRunnable!!, maxDurationMs.toLong())

        // Timer update
        timerRunnable = object : Runnable {
            override fun run() {
                if (isCapturing && !isPaused) {
                    elapsedSeconds++
                    val m = elapsedSeconds / 60
                    val s = elapsedSeconds % 60
                    timerText?.text = String.format("%d:%02d", m, s)
                    handler.postDelayed(this, 1000)
                }
            }
        }
        handler.post(timerRunnable!!)

        // Start frame capture thread
        captureThread = Thread {
            while (isCapturing) {
                if (!isPaused) {
                    val image = imageReader?.acquireLatestImage()
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
                    Thread.sleep(33) // ~30fps
                } catch (e: InterruptedException) {
                    break
                }
            }
        }
        captureThread?.start()

        updateNotification("Scanning in progress...")
    }

    private fun togglePausePlay() {
        if (!isCapturing) return
        isPaused = !isPaused

        if (isPaused) {
            statusText?.text = "Paused"
            pauseLabel?.text = "▶"
            pauseTextLabel?.text = "RESUME"
            timerRunnable?.let { handler.removeCallbacks(it) }
        } else {
            statusText?.text = "Recording"
            pauseLabel?.text = "⏸"
            pauseTextLabel?.text = "PAUSE"
            // Resume timer
            timerRunnable = object : Runnable {
                override fun run() {
                    if (isCapturing && !isPaused) {
                        elapsedSeconds++
                        val m = elapsedSeconds / 60
                        val s = elapsedSeconds % 60
                        timerText?.text = String.format("%d:%02d", m, s)
                        handler.postDelayed(this, 1000)
                    }
                }
            }
            handler.post(timerRunnable!!)
        }
    }

    private fun finishScanning() {
        isCapturing = false
        isPaused = false
        scanBtn?.alpha = 1f
        scanLabel?.text = "⏺"
        scanTextLabel?.text = "START"
        scanBtnWrapper?.isEnabled = true
        pausePlayBtn?.alpha = 0.4f
        pauseBtnWrapper?.isEnabled = false
        pauseLabel?.text = "⏸"
        pauseTextLabel?.text = "PAUSE"
        cancelBtnWrapper?.alpha = 0.4f
        cancelBtnWrapper?.isEnabled = false
        statusText?.text = "Done — ${capturedFrames.size} frames captured"
        timerRunnable?.let { handler.removeCallbacks(it) }
        autoCloseRunnable?.let { handler.removeCallbacks(it) }

        val duration = System.currentTimeMillis() - captureStartTime
        val intent = Intent("com.athena.app.SCAN_COMPLETE").apply {
            putExtra("frameCount", capturedFrames.size)
            putExtra("durationMs", duration.toInt())
        }
        sendBroadcast(intent)

        // Signal Flutter via empty frame
        broadcastScanComplete()

        handler.postDelayed({
            stopSelf()
        }, 2000)
    }

    private fun cancelScanning() {
        isCapturing = false
        isPaused = false
        scanBtn?.alpha = 1f
        scanLabel?.text = "⏺"
        scanTextLabel?.text = "START"
        scanBtnWrapper?.isEnabled = true
        pausePlayBtn?.alpha = 0.4f
        pauseBtnWrapper?.isEnabled = false
        pauseLabel?.text = "⏸"
        pauseTextLabel?.text = "PAUSE"
        cancelBtnWrapper?.alpha = 0.4f
        cancelBtnWrapper?.isEnabled = false
        statusText?.text = "Cancelled — no analysis"
        timerRunnable?.let { handler.removeCallbacks(it) }
        autoCloseRunnable?.let { handler.removeCallbacks(it) }
        capturedFrames.clear()

        // Signal Flutter via empty frame so waitForScanComplete() resolves
        broadcastScanComplete()

        handler.postDelayed({
            stopSelf()
        }, 1500)
    }

    private fun stopCapture() {
        isCapturing = false
        isPaused = false
        captureThread?.interrupt()
        captureThread = null
        timerRunnable?.let { handler.removeCallbacks(it) }
        virtualDisplay?.release()
        imageReader?.close()
        imageReader = null
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

    /** Send an empty frame to signal scan completion to Flutter's EventChannel. */
    private fun broadcastScanComplete() {
        val intent = Intent("com.athena.app.FRAME_CAPTURED").apply {
            putExtra("frame_data", ByteArray(0))
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
        timerRunnable?.let { handler.removeCallbacks(it) }
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
        const val ACTION_CANCEL = "com.athena.app.ACTION_CANCEL"
    }
}
