import 'dart:typed_data';
import 'package:flutter/services.dart';

/// Service to trigger native Android screen capture via MediaProjection
/// The native side handles the MediaProjection permission flow and returns frames.
class ScreenCaptureService {
  static const MethodChannel _channel = MethodChannel('com.athena.app/capture');

  /// Request screen capture permission and start capturing frames.
  /// Returns a stream of captured frame bytes.
  Future<void> startCapture({
    required Function(Uint8List frame) onFrame,
    required Function(String error) onError,
    int maxDurationMs = 10000,
  }) async {
    try {
      await _channel.invokeMethod('startCapture', {
        'max_duration_ms': maxDurationMs,
      });
    } on PlatformException catch (e) {
      onError(e.message ?? 'Failed to start capture');
    }
  }

  /// Stop the current capture session
  Future<void> stopCapture() async {
    try {
      await _channel.invokeMethod('stopCapture');
    } on PlatformException catch (_) {
      // Ignore errors when stopping
    }
  }

  /// Check if screen capture permission is granted
  Future<bool> hasPermission() async {
    try {
      final result = await _channel.invokeMethod<bool>('hasPermission');
      return result ?? false;
    } on PlatformException catch (_) {
      return false;
    }
  }
}
