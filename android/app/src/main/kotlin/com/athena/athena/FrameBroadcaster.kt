package com.athena.athena

import io.flutter.plugin.common.EventChannel

/**
 * Singleton that bridges frame delivery and control events from FloatingOverlayService
 * to Flutter's EventChannel EventSink. Using a direct callback instead of Android
 * Broadcast avoids the ~1MB intent size limit (frames at 1080p are ~8MB in RGBA).
 *
 * Control events are sent as non-Uint8List values (String/Map) so Flutter can
 * distinguish them from frame data.
 *
 * Flow:
 * 1. Flutter's EventChannel.StreamHandler.onListen() → sets frameEventSink here
 * 2. FloatingOverlayService.captureThread → calls sendFrame() → direct to EventSink
 * 3. FloatingOverlayService.createOverlayView() → calls sendScanReady()
 * 4. FloatingOverlayService.finishScanning() → calls sendScanComplete()
 * 5. StreamHandler.onCancel() → clears frameEventSink
 */
object FrameBroadcaster {
    var frameEventSink: EventChannel.EventSink? = null

    fun sendFrame(frameData: ByteArray) {
        // Always send ByteArray for frame data
        frameEventSink?.success(frameData)
    }

    fun sendScanReady() {
        // Non-frame signal — Flutter interprets this as "navigate to ScanningScreen"
        frameEventSink?.success("scan_ready")
    }

    fun sendScanComplete() {
        // null signals end of capture
        frameEventSink?.success(null)
    }
}
