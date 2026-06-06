import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

/// Service to trigger native Android screen capture via MediaProjection.
/// Frames arrive via EventChannel as raw RGBA bytes and are converted to PNG
/// before being stored. Scan completion is signaled via a broadcast intent.
class ScreenCaptureService {
  static const MethodChannel _channel = MethodChannel('com.athena.app/capture');
  static const EventChannel _frameChannel =
      EventChannel('com.athena.app/capture/frames');

  // Screen dimensions received from native side
  int _screenWidth = 0;
  int _screenHeight = 0;

  // Captured PNG frames
  final List<Uint8List> _frames = [];

  // Signals scan completion
  final Completer<void> _scanCompleter = Completer<void>();

  StreamSubscription? _frameSubscription;
  bool _captureStarted = false;

  // ── Public API ─────────────────────────────────────────────────────────────

  /// List of captured PNG-encoded frames.
  List<Uint8List> get frames => List.unmodifiable(_frames);

  /// Returns a Future that completes when the native side signals scan complete.
  /// The native side calls FloatingOverlayService.finishScanning() which sends
  /// the SCAN_COMPLETE broadcast; we listen for it via the frame EventChannel
  /// (which closes on scan end) or via a dedicated broadcast receiver.
  Future<void> waitForScanComplete() => _scanCompleter.future;

  /// Request screen capture permission and start capturing frames.
  /// Returns quickly after permission is granted; actual completion is signaled
  /// via waitForScanComplete().
  Future<void> startCapture({
    required Function(Uint8List frame) onFrame,
    required Function(String error) onError,
    int maxDurationMs = 10000,
  }) async {
    if (_captureStarted) return;
    _captureStarted = true;

    try {
      // Ask native side for screen dimensions
      final dims = await _channel.invokeMethod<Map<dynamic, dynamic>>('getScreenDimensions');
      if (dims != null) {
        _screenWidth = (dims['width'] as num).toInt();
        _screenHeight = (dims['height'] as num).toInt();
      }

      // Start capture on native side
      await _channel.invokeMethod('startCapture', {
        'max_duration_ms': maxDurationMs,
      });

      // Listen for frames via EventChannel
      _frameSubscription = _frameChannel.receiveBroadcastStream().listen(
        (dynamic data) {
          if (data == null) {
            // Null signals end of capture — complete the scan future
            if (!_scanCompleter.isCompleted) {
              _scanCompleter.complete();
            }
            return;
          }

          if (data is Uint8List && _screenWidth > 0 && _screenHeight > 0) {
            // Convert RGBA raw bytes → PNG using the image package
            final pngBytes = _rgbaToPng(data, _screenWidth, _screenHeight);
            if (pngBytes != null) {
              _frames.add(pngBytes);
              onFrame(pngBytes);
            }
          }
        },
        onError: (error) {
          onError(error.toString());
          if (!_scanCompleter.isCompleted) {
            _scanCompleter.complete();
          }
        },
      );
    } on PlatformException catch (e) {
      onError(e.message ?? 'Failed to start capture');
      if (!_scanCompleter.isCompleted) {
        _scanCompleter.complete();
      }
    }
  }

  /// Stop the current capture session.
  Future<void> stopCapture() async {
    if (!_captureStarted) return;
    _captureStarted = false;
    await _frameSubscription?.cancel();
    _frameSubscription = null;
    try {
      await _channel.invokeMethod('stopCapture');
    } on PlatformException catch (_) {
      // Ignore errors when stopping
    }
    if (!_scanCompleter.isCompleted) {
      _scanCompleter.complete();
    }
  }

  /// Check if screen capture permission is granted.
  Future<bool> hasPermission() async {
    try {
      final result = await _channel.invokeMethod<bool>('hasPermission');
      return result ?? false;
    } on PlatformException catch (_) {
      return false;
    }
  }

  // ── RGBA → PNG conversion ───────────────────────────────────────────────────

  /// Converts raw RGBA bytes (PixelFormat.RGBA_8888) to a PNG-encoded Uint8List.
  img.Image? _rgbaToImage(Uint8List rgbaBytes, int width, int height) {
    try {
      final image = img.Image(width: width, height: height);
      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final idx = (y * width + x) * 4;
          if (idx + 3 < rgbaBytes.length) {
            image.setPixelRgba(
              x,
              y,
              rgbaBytes[idx],     // R
              rgbaBytes[idx + 1], // G
              rgbaBytes[idx + 2], // B
              rgbaBytes[idx + 3], // A
            );
          }
        }
      }
      return image;
    } catch (_) {
      return null;
    }
  }

  Uint8List? _rgbaToPng(Uint8List rgbaBytes, int width, int height) {
    final image = _rgbaToImage(rgbaBytes, width, height);
    if (image == null) return null;
    return Uint8List.fromList(img.encodePng(image));
  }
}
