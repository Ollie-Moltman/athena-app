import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:athena/main.dart';
import 'package:athena/services/screen_capture_service.dart';
import 'scanning_screen.dart';
import 'dart:async';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> with WidgetsBindingObserver {
  bool _isCapturing = false;
  bool _permissionDenied = false;
  StreamSubscription? _scanReadySub;

  static const MethodChannel _channel = MethodChannel('com.athena.app/capture');
  final ScreenCaptureService _captureService = ScreenCaptureService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scanReadySub?.cancel();
    _captureService.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Reset capturing state when returning from Settings redirect,
      // then retry the scan if we were waiting for permission
      if (_isCapturing && _permissionDenied) {
        setState(() => _isCapturing = false);
        _permissionDenied = false;
        _startScanning();
      }
    }
  }

  /// Check current permission state and update UI.
  Future<bool> _checkPermissions() async {
    try {
      // hasPermission returns true only after MediaProjection was granted.
      final hasMediaProjection = await _channel.invokeMethod<bool>('hasPermission') ?? false;
      return hasMediaProjection;
    } catch (_) {
      return false;
    }
  }

  Future<void> _startScanning() async {
    if (settingsService == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settings unavailable. Please restart the app.'),
          backgroundColor: Color(0xFFEF4444),
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    if (settingsService.scansRemaining <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Daily scan limit reached. Resets at midnight.'),
          backgroundColor: Color(0xFFEF4444),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    setState(() => _isCapturing = true);

    // Listen for the overlay-ready signal from FloatingOverlayService.
    // When the overlay is created, FloatingOverlayService.sendScanReady() is called
    // which sends "scan_ready" through the EventChannel. We navigate then.
    _scanReadySub?.cancel();
    _scanReadySub = _captureService.scanReady.listen((_) {
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const ScanningScreen(permissionGranted: true),
        ),
      ).then((_) {
        if (mounted) setState(() => _isCapturing = false);
      });
    });

    try {
      // Native returns:
      //   "overlay_required" = overlay permission missing, sent to Settings
      //   anything else (including void/null) = permission flow started,
      //       overlay will be shown; "scan_ready" event will follow.
      //   "denied" = user denied
      // A PlatformException is thrown if the method is not implemented.
      final result = await _channel.invokeMethod<String>('startCapture', {
        'max_duration_ms': settingsService?.maxDurationMs ?? 20000,
      });

      if (!mounted) return;

      if (result == 'overlay_required') {
        // Overlay permission was missing — user was sent to Settings.
        // They need to grant it and come back to scan.
        // Cancel the scanReady listener since no overlay will appear.
        _scanReadySub?.cancel();
        _scanReadySub = null;
        _captureService.reset(); // Clear stale _captureStarted so next tap works
        setState(() => _isCapturing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📱 Please enable "Display over other apps" in Settings > Apps > Athena, then tap SCAN again'),
            backgroundColor: Color(0xFFF59E0B),
            duration: Duration(seconds: 6),
          ),
        );
      } else if (result == 'denied') {
        _scanReadySub?.cancel();
        _scanReadySub = null;
        setState(() {
          _isCapturing = false;
          _permissionDenied = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Screen capture denied. Please grant permission and try again.'),
            backgroundColor: Color(0xFFF59E0B),
            duration: Duration(seconds: 5),
          ),
        );
      }
      // For any other result (ok, null, etc.) we just wait for scan_ready
    } on PlatformException catch (_) {
      // Method not implemented or other error
      _scanReadySub?.cancel();
      _scanReadySub = null;
      if (!mounted) return;
      setState(() => _isCapturing = false);
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const ScanningScreen(permissionGranted: false),
        ),
      ).then((_) {
        if (mounted) setState(() => _isCapturing = false);
      });
    }
  }

  /// Open system app settings page so user can grant overlay permission manually.
  Future<void> _openPermissionSettings() async {
    try {
      await _channel.invokeMethod('openPermissionSettings');
    } on PlatformException catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open settings. Please open Settings > Apps > Athena manually.'),
          backgroundColor: Color(0xFFF59E0B),
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '🔍 Athena',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A2E),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${settingsService.scansRemaining} scans left',
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.history, color: Colors.white54),
                        onPressed: () => Navigator.pushNamed(context, '/history'),
                      ),
                      IconButton(
                        icon: const Icon(Icons.settings, color: Colors.white54),
                        onPressed: () => Navigator.pushNamed(context, '/settings'),
                      ),
                    ],
                  ),
                ],
              ),
              const Spacer(),
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A2E),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Icon(
                  Icons.smart_display,
                  size: 60,
                  color: Color(0xFF6366F1),
                ),
              ),
              const SizedBox(height: 40),
              const Text(
                'Ready to detect\nAI-generated video?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Open any video app first, then tap SCAN.\nThe floating overlay will appear over your video.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white54,
                  height: 1.5,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A2E),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    _buildStep('1', 'Open any video (YouTube, Instagram, etc.)'),
                    const SizedBox(height: 12),
                    _buildStep('2', 'Tap the red SCAN button below'),
                    const SizedBox(height: 12),
                    _buildStep('3', 'Select "Entire screen" or an app'),
                    const SizedBox(height: 12),
                    _buildStep('4', 'Tap ⏺ to start scanning'),
                    const SizedBox(height: 12),
                    _buildStep('5', 'Tap ⏹ to finish & see results'),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: _isCapturing ? null : _startScanning,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: _isCapturing
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.play_arrow_rounded, size: 28),
                            SizedBox(width: 8),
                            Text(
                              'SCAN',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 16),
              // Dedicated permissions button — easy access to grant overlay permission
              OutlinedButton.icon(
                onPressed: _openPermissionSettings,
                icon: const Icon(Icons.settings_applications, size: 18),
                label: const Text('Grant Permissions'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white54,
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Enable "Display over other apps" for Athena to show the scanning overlay',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white30,
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildStep(String number, String text) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: const Color(0xFF6366F1).withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                color: Color(0xFF6366F1),
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
}