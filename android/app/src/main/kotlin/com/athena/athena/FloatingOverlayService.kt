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
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                    WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.BOTTOM or Gravity.CENTER_HORIZONTAL
        }

        try {
            windowManager?.addView(overlayView, params)
        } catch (e: Exception) {
            // May fail without SYSTEM_ALERT_WINDOW permission — notify user
            try {
                android.widget.Toast.makeText(
                    this,
                    "Athena needs Display Over Other Apps permission. Check Settings > Apps > Athena > Display over other apps.",
                    android.widget.Toast.LENGTH_LONG
                ).show()
            } catch (_: Exception) {}
        }

        // Build the pill-shaped overlay
        val container = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(0xE61A1A2E.toInt())
            setPadding(20, 16, 20, 16)
        }

        // Top row: rec dot + status + timer
        val topRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(0, 0, 0, 12)
        }

        // Red rec dot (small square)
        recDot = TextView(this).apply {
            text = "■"
            setTextColor(0xFFF85149.toInt())
            textSize = 10f
        }
        (recDot!!.layoutParams as LinearLayout.LayoutParams).marginEnd = 8

        statusText = TextView(this).apply {
            text = "Ready"
            setTextColor(0xFFA0A0A0.toInt())
            textSize = 13f
        }

        timerText = TextView(this).apply {
            text = "0:00"
            setTextColor(0xFFFFFFFF.toInt())
            textSize = 13f
            setPadding(16, 0, 16, 0)
        }

        topRow.addView(recDot)
        topRow.addView(statusText)
        topRow.addView(timerText)

        // Button row
        val btnRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
        }

        // SCAN button (red circle with ⏺ symbol)
        scanBtn = ImageView(this).apply {
            setBackgroundColor(0xFFF85149.toInt())
            alpha = 1f
        }
        scanBtnWrapper = FrameLayout(this)
        scanBtnWrapper?.layoutParams = LinearLayout.LayoutParams(56, 56).apply { marginEnd = 16 }
        scanLabel = TextView(this).apply {
            text = "⏺"
            setTextColor(0xFFFFFFFF.toInt())
            textSize = 22f
            gravity = Gravity.CENTER
        }
        scanBtnWrapper?.addView(scanBtn, FrameLayout.LayoutParams(56, 56).apply { gravity = Gravity.CENTER })
        scanBtnWrapper?.addView(scanLabel, FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT).apply { gravity = Gravity.CENTER })
        scanBtnWrapper?.setOnClickListener { sendBroadcast(Intent(ACTION_SCAN)) }

        // PAUSE button (purple circle with ⏸)
        pausePlayBtn = ImageView(this).apply {
            setBackgroundColor(0xFF8B5CF6.toInt())
            alpha = 0.5f
        }
        pauseBtnWrapper = FrameLayout(this)
        pauseBtnWrapper?.layoutParams = LinearLayout.LayoutParams(48, 48).apply { marginEnd = 16 }
        pauseLabel = TextView(this).apply {
            text = "⏸"
            setTextColor(0xFFFFFFFF.toInt())
            textSize = 18f
            gravity = Gravity.CENTER
        }
        pauseBtnWrapper?.addView(pausePlayBtn, FrameLayout.LayoutParams(48, 48).apply { gravity = Gravity.CENTER })
        pauseBtnWrapper?.addView(pauseLabel, FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT).apply { gravity = Gravity.CENTER })
        pauseBtnWrapper?.setOnClickListener { sendBroadcast(Intent(ACTION_PAUSE_PLAY)) }

        // FINISH button (green circle with ✕)
        val cancelBtn = ImageView(this).apply {
            setBackgroundColor(0xFF10B981.toInt())
            alpha = 0.5f
        }
        cancelBtnWrapper = FrameLayout(this)
        cancelBtnWrapper?.layoutParams = LinearLayout.LayoutParams(48, 48)
        cancelLabel = TextView(this).apply {
            text = "✕"
            setTextColor(0xFFFFFFFF.toInt())
            textSize = 18f
            gravity = Gravity.CENTER
        }
        cancelBtnWrapper?.addView(cancelBtn, FrameLayout.LayoutParams(48, 48).apply { gravity = Gravity.CENTER })
        cancelBtnWrapper?.addView(cancelLabel, FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT).apply { gravity = Gravity.CENTER })
        cancelBtnWrapper?.setOnClickListener { sendBroadcast(Intent(ACTION_CANCEL)) }


        btnRow.addView(scanBtnWrapper)
        btnRow.addView(pauseBtnWrapper)
        btnRow.addView(cancelBtnWrapper)

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

        // Set up MediaProjection + ImageReader if not already done
        if (imageReader == null) {
            setupCapture()
        }

        isCapturing = true
        isPaused = false

        // Update UI: scan button shows ⏹ (finish), pause/cancel become active
        scanBtn?.alpha = 1f
        scanLabel?.text = "⏹"
        scanBtnWrapper?.isEnabled = true
        pausePlayBtn?.alpha = 1f
        pauseBtnWrapper?.isEnabled = true
        pauseLabel?.text = "⏸"
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
            timerRunnable?.let { handler.removeCallbacks(it) }
        } else {
            statusText?.text = "Recording"
            pauseLabel?.text = "⏸"
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
        scanBtnWrapper?.isEnabled = true
        pausePlayBtn?.alpha = 0.5f
        pauseBtnWrapper?.isEnabled = false
        cancelBtnWrapper?.alpha = 0.5f
        cancelBtnWrapper?.isEnabled = false
        statusText?.text = "Done ${capturedFrames.size} frames"
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
        scanBtnWrapper?.isEnabled = true
        pausePlayBtn?.alpha = 0.5f
        pauseBtnWrapper?.isEnabled = false
        cancelBtnWrapper?.alpha = 0.5f
        cancelBtnWrapper?.isEnabled = false
        statusText?.text = "Cancelled"
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
