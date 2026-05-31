import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import '../../services/local_detection_service.dart';
import '../../models/scan_result.dart';
import 'results_screen.dart';

class ScanningScreen extends StatefulWidget {
  const ScanningScreen({super.key});

  @override
  State<ScanningScreen> createState() => _ScanningScreenState();
}

class _ScanningScreenState extends State<ScanningScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  final LocalDetectionService _detectionService = LocalDetectionService();
  String _currentLayer = 'Initializing...';
  int _progress = 0;
  bool _isPaused = false;

  final List<_LayerInfo> _layers = const [
    _LayerInfo('Provenance', 'Checking capture metadata...', 1),
    _LayerInfo('Visual Artifacts', 'Analyzing frame patterns...', 2),
    _LayerInfo('Deep Learning', 'Running ML classification...', 3),
    _LayerInfo('Contextual', 'Cross-referencing signals...', 4),
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _startScan();
  }

  Future<void> _startScan() async {
    // Capture frames via platform channel (MediaProjection)
    // For now: use placeholder frames until real capture is wired
    final frames = await _captureFrames();

    for (var layer in _layers) {
      if (_isPaused) await _waitWhilePaused();

      setState(() {
        _currentLayer = layer.label;
        _progress = layer.index;
      });

      await Future.delayed(Duration(milliseconds: 600 + layer.index * 300));
    }

    setState(() => _progress = 4);

    // Run on-device detection
    final result = await _detectionService.analyze(
      frames: frames,
      durationMs: 3000,
    );

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ResultsScreen(result: result),
      ),
    );
  }

  Future<List<Uint8List>> _captureFrames() async {
    // TODO: Wire to ScreenCaptureService platform channel
    // For MVP: generate synthetic test frames to demonstrate detection
    return _generateTestFrames();
  }

  List<Uint8List> _generateTestFrames() {
    // Generate 10 synthetic frames for MVP testing
    // These demonstrate the detection pipeline working
    final frames = <Uint8List>[];
    final image = img.Image(width: 640, height: 480);

    // Fill with a synthetic-looking gradient
    for (int y = 0; y < 480; y++) {
      for (int x = 0; x < 640; x++) {
        final r = ((x * 0.5) % 256).toInt();
        final g = ((y * 0.3) % 256).toInt();
        final b = (((x + y) * 0.4) % 256).toInt();
        image.setPixel(x, y, img.ColorRgb8(r, g, b));
      }
    }

    // Add some "content" blocks to simulate real video
    for (int y = 100; y < 380; y++) {
      for (int x = 100; x < 540; x++) {
        if (y > 200 && y < 280 && x > 200 && x < 440) {
          // Dark center block (face-like region)
          image.setPixel(x, y, img.ColorRgb8(30, 30, 50));
        }
      }
    }

    final png = img.encodePng(image);
    frames.add(png);

    // Add slight variations for temporal analysis
    for (int i = 1; i < 10; i++) {
      final variant = img.Image(width: 640, height: 480);
      for (int y = 0; y < 480; y++) {
        for (int x = 0; x < 640; x++) {
          final noise = (i * 5) % 20;
          final p = image.getPixel(x, y);
          variant.setPixel(
            x, y,
            img.ColorRgb8(
              (p.r.toInt() + noise).clamp(0, 255),
              (p.g.toInt() + noise).clamp(0, 255),
              (p.b.toInt() + noise).clamp(0, 255),
            ),
          );
        }
      }
      frames.add(img.encodePng(variant));
    }

    return frames;
  }

  Future<void> _waitWhilePaused() async {
    while (_isPaused) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  void _togglePause() {
    setState(() => _isPaused = !_isPaused);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
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
              // Header
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Spacer(),
                  const Text(
                    'Scanning',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 48),
                ],
              ),

              const Spacer(),

              // Animated scanning circle
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0xFF6366F1)
                              .withOpacity(0.3 + _pulseController.value * 0.3),
                          blurRadius: 20 + _pulseController.value * 20,
                          spreadRadius: 2 + _pulseController.value * 5,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.document_scanner_outlined,
                            size: 48,
                            color: Colors.white,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '$_progress / 4',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 40),

              Text(
                _currentLayer,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),

              const SizedBox(height: 8),

              // Progress dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (index) {
                  final isActive = index < _progress;
                  final isCurrent = index == _progress - 1;
                  return Container(
                    width: isCurrent ? 24 : 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: isActive
                          ? const Color(0xFF6366F1)
                          : Colors.white.withOpacity(0.2),
                    ),
                  );
                }),
              ),

              const Spacer(),

              // Pause / Resume button
              GestureDetector(
                onTap: _togglePause,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A2E),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: const Color(0xFF6366F1).withOpacity(0.5),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isPaused ? Icons.play_arrow : Icons.pause,
                        color: Colors.white70,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isPaused ? 'Resume' : 'Pause',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.white38),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LayerInfo {
  final String label;
  final String description;
  final int index;

  const _LayerInfo(this.label, this.description, this.index);
}
