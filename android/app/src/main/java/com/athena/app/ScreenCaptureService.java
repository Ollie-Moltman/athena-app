package com.athena.app;

import android.app.Activity;
import android.app.ActivityManager;
import android.content.Context;
import android.content.Intent;
import android.hardware.display.DisplayManager;
import android.hardware.display.VirtualDisplay;
import android.media.ImageReader;
import android.media.Image;
import android.media.projection.MediaProjection;
import android.media.projection.MediaProjectionManager;
import android.os.Handler;
import android.os.Looper;
import android.util.DisplayMetrics;
import android.view.PixelCopy;

import androidx.annotation.NonNull;

import java.io.ByteArrayOutputStream;
import java.nio.ByteBuffer;
import java.util.ArrayList;
import java.util.List;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

/**
 * Native Android screen capture via MediaProjection API.
 * Handles permission flow and frame capture for Athena app.
 */
public class ScreenCaptureService implements MethodChannel.MethodCallHandler {

    private static final String CHANNEL = "com.athena.app/capture";
    private static final int PERMISSION_REQUEST_CODE = 1001;

    private FlutterActivity activity;
    private MethodChannel channel;
    private MethodChannel.Result pendingResult;

    private MediaProjectionManager projectionManager;
    private MediaProjection mediaProjection;
    private VirtualDisplay virtualDisplay;
    private ImageReader imageReader;

    private boolean isCapturing = false;
    private List<byte[]> capturedFrames = new ArrayList<>();
    private int maxDurationMs = 3000;
    private long captureStartTime;

    public static void registerWith(FlutterEngine engine, FlutterActivity activity) {
        ScreenCaptureService service = new ScreenCaptureService(activity);
        MethodChannel channel = new MethodChannel(engine.getDartExecutor(), CHANNEL);
        channel.setMethodCallHandler(service);
        service.channel = channel;
    }

    private ScreenCaptureService(FlutterActivity activity) {
        this.activity = activity;
        this.projectionManager = (MediaProjectionManager)
            activity.getSystemService(Context.MEDIA_PROJECTION_SERVICE);
    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
        switch (call.method) {
            case "startCapture":
                int maxDuration = call.argument("max_duration_ms") != null
                    ? call.argument("max_duration_ms") : 3000;
                startCapture(maxDuration, result);
                break;
            case "stopCapture":
                stopCapture();
                result.success(null);
                break;
            case "hasPermission":
                // MediaProjection always asks on first startCapture call
                result.success(false);
                break;
            default:
                result.notImplemented();
        }
    }

    private void startCapture(int maxDurationMs, MethodChannel.Result result) {
        this.maxDurationMs = maxDurationMs;
        this.pendingResult = result;
        this.capturedFrames.clear();

        // Launch the system permission dialog
        Intent permissionIntent = projectionManager.createScreenCaptureIntent();
        activity.startActivityForResult(permissionIntent, PERMISSION_REQUEST_CODE);
    }

    /**
     * Called from FlutterActivity.onActivityResult()
     */
    public void onActivityResult(int requestCode, int resultCode, Intent data) {
        if (requestCode != PERMISSION_REQUEST_CODE) return;

        if (resultCode == Activity.RESULT_OK && data != null) {
            initializeProjection(data);
            if (pendingResult != null) {
                pendingResult.success(true);
                pendingResult = null;
            }
        } else {
            if (pendingResult != null) {
                pendingResult.error("PERMISSION_DENIED", "Screen capture denied", null);
                pendingResult = null;
            }
        }
    }

    private void initializeProjection(Intent data) {
        mediaProjection = projectionManager.getMediaProjection(
            Activity.RESULT_OK, data);

        DisplayMetrics metrics = activity.getResources().getDisplayMetrics();
        int width = metrics.widthPixels;
        int height = metrics.heightPixels;
        int density = metrics.densityDpi;

        // ImageReader for capturing frames
        imageReader = ImageReader.newInstance(width, height,
            android.graphics.ImageFormat.YUV_420_888, 2);

        virtualDisplay = mediaProjection.createVirtualDisplay(
            "AthenaCapture",
            width, height, density,
            DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR,
            imageReader.getSurface(), null, null);

        isCapturing = true;
        captureStartTime = System.currentTimeMillis();

        // Start frame capture loop
        new Thread(this::captureLoop).start();
    }

    private void captureLoop() {
        Handler mainHandler = new Handler(Looper.getMainLooper());
        long endTime = captureStartTime + maxDurationMs;

        while (isCapturing && System.currentTimeMillis() < endTime) {
            Image image = imageReader.acquireLatestImage();
            if (image != null) {
                try {
                    ByteBuffer buffer = image.getPlanes()[0].getBuffer();
                    byte[] bytes = new byte[buffer.remaining()];
                    buffer.get(bytes);
                    capturedFrames.add(bytes);

                    // Send frame to Flutter via channel
                    byte[] frameData = bytes;
                    mainHandler.post(() -> {
                        if (channel != null) {
                            channel.invokeMethod("onFrame",
                                new java.util.HashMap() {{ put("frame", frameData); }});
                        }
                    });
                } finally {
                    image.close();
                }
            }

            try {
                Thread.sleep(33); // ~30 fps
            } catch (InterruptedException e) {
                break;
            }
        }

        // Capture complete — send final result
        final List<byte[]> frames = new ArrayList<>(capturedFrames);
        mainHandler.post(() -> {
            if (channel != null) {
                channel.invokeMethod("onCaptureComplete",
                    new java.util.HashMap() {{
                        put("frames_count", frames.size());
                        put("duration_ms", System.currentTimeMillis() - captureStartTime);
                    }});
            }
        });

        cleanup();
    }

    private void stopCapture() {
        isCapturing = false;
        cleanup();
    }

    private void cleanup() {
        if (virtualDisplay != null) {
            virtualDisplay.release();
            virtualDisplay = null;
        }
        if (imageReader != null) {
            imageReader.close();
            imageReader = null;
        }
        if (mediaProjection != null) {
            mediaProjection.stop();
            mediaProjection = null;
        }
    }
}
