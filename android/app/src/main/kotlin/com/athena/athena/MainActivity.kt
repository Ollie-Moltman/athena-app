package com.athena.athena

import android.app.Activity
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.display.DisplayManager
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.athena.app/capture"
    private val FRAME_CHANNEL = "com.athena.app/capture/frames"

    private var mediaProjectionManager: MediaProjectionManager? = null
    private var mediaProjection: MediaProjection? = null
    private var frameEventSink: EventChannel.EventSink? = null
    private val handler = Handler(Looper.getMainLooper())

    private var pendingResult: MethodChannel.Result? = null
    private var pendingMaxDuration = 30000

    // BroadcastReceiver to receive frames from FloatingOverlayService
    private val frameReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            val frameData = intent?.getByteArrayExtra("frame_data")
            if (frameData != null && frameEventSink != null) {
                handler.post {
                    if (frameData.isEmpty()) {
                        // Empty frame = scan complete signal → resolve Flutter's waitForScanComplete()
                        frameEventSink?.success(null)
                    } else {
                        frameEventSink?.success(frameData)
                    }
                }
            }
        }
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        mediaProjectionManager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startCapture" -> {
                    // First check if we have SYSTEM_ALERT_WINDOW permission
                    if (!Settings.canDrawOverlays(this)) {
                        // Need to request overlay permission first
                        val overlayIntent = Intent(
                            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                            android.net.Uri.parse("package:$packageName")
                        )
                        overlayIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(overlayIntent)
                        result.success(false)
                    } else {
                        val permissionIntent = mediaProjectionManager?.createScreenCaptureIntent()
                        if (permissionIntent == null) {
                            result.success(false)
                        } else {
                            startActivityForResult(permissionIntent, SCREEN_CAPTURE_REQUEST_CODE)
                            pendingResult = result
                            pendingMaxDuration = call.argument<Int>("max_duration_ms") ?: 30000
                        }
                    }
                }
                "stopCapture" -> {
                    val intent = Intent(this, FloatingOverlayService::class.java)
                    stopService(intent)
                    result.success(null)
                }
                "hasPermission" -> {
                    // We track this via a flag since MediaProjection permission is one-shot
                    result.success(hasMediaProjectionPermission)
                }
                "getAvailableDisplays" -> {
                    val displays = getSystemService(Context.DISPLAY_SERVICE) as DisplayManager
                    result.success(displays.displays.map { it.displayId.toString() })
                }
                "getScreenDimensions" -> {
                    val metrics = resources.displayMetrics
                    result.success(mapOf("width" to metrics.widthPixels, "height" to metrics.heightPixels))
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, FRAME_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    frameEventSink = events
                    val filter = IntentFilter("com.athena.app.FRAME_CAPTURED")
                    registerReceiver(frameReceiver, filter)
                }

                override fun onCancel(arguments: Any?) {
                    frameEventSink = null
                    try {
                        unregisterReceiver(frameReceiver)
                    } catch (_: Exception) {}
                }
            }
        )
    }

    private var hasMediaProjectionPermission = false
    private var resultCode: Int? = null
    private var resultData: Intent? = null

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == SCREEN_CAPTURE_REQUEST_CODE) {
            if (resultCode == Activity.RESULT_OK && data != null) {
                hasMediaProjectionPermission = true
                this.resultCode = resultCode
                this.resultData = data

                mediaProjection = mediaProjectionManager?.getMediaProjection(resultCode, data)
                mediaProjection?.registerCallback(object : MediaProjection.Callback() {
                    override fun onStop() {
                        mediaProjection?.stop()
                        mediaProjection = null
                        hasMediaProjectionPermission = false
                    }
                }, null)

                val serviceIntent = Intent(this, FloatingOverlayService::class.java).apply {
                    putExtra("resultCode", resultCode)
                    putExtra("data", data)
                    putExtra("maxDurationMs", pendingMaxDuration)
                }
                startForegroundService(serviceIntent)
                pendingResult?.success(true)
            } else {
                pendingResult?.success(false)
            // Stop any stale FloatingOverlayService so retry works cleanly
            val stopIntent = Intent(this, FloatingOverlayService::class.java)
            stopService(stopIntent)
            }
            pendingResult = null
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        try {
            unregisterReceiver(frameReceiver)
        } catch (_: Exception) {}
        mediaProjection?.stop()
    }

    companion object {
        const val SCREEN_CAPTURE_REQUEST_CODE = 9999
    }
}
