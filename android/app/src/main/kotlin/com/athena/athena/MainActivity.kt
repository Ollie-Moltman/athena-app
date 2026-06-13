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
    private var pendingResult: MethodChannel.Result? = null
    private var pendingMaxDuration = 30000

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
                        // Set flag so onResume() retries capture after user returns
                        pendingOverlayRetry = true
                        pendingResult = result
                        pendingMaxDuration = call.argument<Int>("max_duration_ms") ?: 30000
                        // Return early — result will be resolved after user grants overlay
                        result.success("overlay_required")
                    } else {
                        // Overlay already granted — go straight to MediaProjection
                        val permissionIntent = mediaProjectionManager?.createScreenCaptureIntent()
                        if (permissionIntent == null) {
                            result.success("denied")
                        } else {
                            startActivityForResult(permissionIntent, SCREEN_CAPTURE_REQUEST_CODE)
                            pendingResult = result
                            pendingMaxDuration = call.argument<Int>("max_duration_ms") ?: 30000
                            // Don't resolve yet — wait for onActivityResult
                        }
                    }
                }
                "openPermissionSettings" -> {
                    val overlayIntent = Intent(
                        Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                        android.net.Uri.parse("package:$packageName")
                    )
                    overlayIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    startActivity(overlayIntent)
                    result.success(null)
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
                    // Register the EventSink with our singleton so FloatingOverlayService
                    // can call it directly, bypassing Android's 1MB broadcast limit
                    FrameBroadcaster.frameEventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    FrameBroadcaster.frameEventSink = null
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
                pendingResult?.success("ok")
            } else {
                // User denied screen capture
                pendingResult?.success("denied")
                pendingResult = null
                pendingOverlayRetry = false
                // Stop any stale FloatingOverlayService so retry works cleanly
                val stopIntent = Intent(this, FloatingOverlayService::class.java)
                stopService(stopIntent)
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        FrameBroadcaster.frameEventSink = null
        mediaProjection?.stop()
    }

    // Track whether we need to retry capture after returning from overlay settings
    private var pendingOverlayRetry = false

    override fun onResume() {
        super.onResume()
        if (pendingOverlayRetry && Settings.canDrawOverlays(this)) {
            pendingOverlayRetry = false
            // Overlay permission now granted — retry screen capture flow.
            val r = pendingResult
            if (r != null) {
                val permissionIntent = mediaProjectionManager?.createScreenCaptureIntent()
                if (permissionIntent == null) {
                    r.success("denied")
                    pendingResult = null
                } else {
                    // Start the MediaProjection intent. pendingResult must survive
                    // the startActivityForResult call so onActivityResult can use it.
                    startActivityForResult(permissionIntent, SCREEN_CAPTURE_REQUEST_CODE)
                    // Don't null out pendingResult here — onActivityResult needs it.
                    // If onActivityResult never fires (crash, etc.), pendingResult
                    // will be cleaned up on the next startCapture call.
                }
            } else {
                // pendingResult is null means user went to Settings but didn't grant overlay
                // and returned. Clear the retry flag so next SCAN tap starts fresh.
                android.util.Log.w("Athena", "pendingResult was null on overlay retry — clearing flag")
                pendingResult = null
            }
        }
    }

    companion object {
        const val SCREEN_CAPTURE_REQUEST_CODE = 9999
    }
}
