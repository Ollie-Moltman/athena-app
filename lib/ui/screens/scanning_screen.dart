import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/screen_capture_service.dart';
import '../../services/local_detection_service.dart';
import '../../main.dart';
import 'results_screen.dart';

class ScanningScreen extends StatefulWidget {
  final bool permissionGranted;

  const ScanningScreen({super.key, required this.permissionGranted});

  @override
  State<ScanningScreen> createState() => _ScanningScreenState();
}

class _ScanningScreenState extends State<ScanningScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  final ScreenCaptureService _captureService = ScreenCaptureService();
  final LocalDetectionService _detectionService = LocalDetectionService();

  String _currentLayer = 'Initializing...';
  int _progress = 0;
  String? _errorMessage;
  final List<String> _logLines = [];
  int _capturedFrames = 0;
  bool _analysisStarted = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    if (widget.permissionGranted) {
      _startRealCapture();
    } else {
      _startDemoCapture();
    }
  }

  Future<void> _startRealCapture() async {
    setState(() {
      _currentLayer = 'Requesting screen capture...';
      _progress = 1;
      _logLines.add('Starting capture with maxDuration=${settingsService.maxDurationMs}ms');
    });

    await _captureService.startCapture(
      isMounted: mounted,
      onFrame: (frame) {
        setState(() {
          _capturedFrames++;
          if (_logLines.length < 5) {
            _logLines.add('Frame $_capturedFrames: ${frame.length} bytes');
          }
        });
      },
      onError: (error) {
        setState(() {
          _errorMessage = error;
          _logLines.add('Error: $error');
        });
      },
      maxDurationMs: settingsService.maxDurationMs,
    );

    if (!mounted) return;

    setState(() {
      _currentLayer = 'Capturing frames...';
      _progress = 2;
    });

    // Wait for native side to signal scan complete via EventChannel/broadcast
    if (!mounted) return;
    _analysisStarted = true; // Set BEFORE await to close race window
    await _captureService.waitForScanComplete();

    if (!mounted) return;

    final capturedFrames = _captureService.frames;
    _logLines.add('Scan complete — ${capturedFrames.length} frames captured');

    if (capturedFrames.isEmpty) {
      _logLines.add('No frames captured, falling back to demo mode');
      await _startDemoCapture();
    } else {
      await _runAnalysisWithFrames(capturedFrames, settingsService.maxDurationMs);
    }
  }

  Future<void> _startDemoCapture() async {
    // Reset any stale capture state before starting demo
    _captureService.stopCapture();

    if (!mounted) return;
    setState(() {
      _currentLayer = 'Demo mode — analyzing...';
      _progress = 2;
      _logLines.add('Demo mode active');
    });

    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;
    setState(() => _capturedFrames = 30);
    _logLines.add('Demo: 30 synthetic frames');

    await _runAnalysis(30, 2000);
  }

  /// Run analysis with real captured frames.
  Future<void> _runAnalysisWithFrames(List<dynamic> frames, int durationMs) async {
    if (!mounted) return;

    setState(() {
      _currentLayer = 'Layer 1: Provenance';
      _progress = 2;
    });
    await Future.delayed(const Duration(milliseconds: 700));

    if (!mounted) return;
    setState(() {
      _currentLayer = 'Layer 2: Visual Artifacts';
      _progress = 3;
    });
    await Future.delayed(const Duration(milliseconds: 800));

    if (!mounted) return;
    setState(() {
      _currentLayer = 'Layer 3: Deep Learning';
      _progress = 4;
    });
    await Future.delayed(const Duration(milliseconds: 800));

    if (!mounted) return;
    setState(() {
      _currentLayer = 'Layer 4: Contextual';
      _progress = 5;
    });
    await Future.delayed(const Duration(milliseconds: 600));

    if (!mounted) return;
    setState(() {
      _currentLayer = 'Generating verdict...';
      _progress = 6;
    });

    // Pass captured PNG frames to the detection service
    final result = await _detectionService.analyze(
      frames: frames.cast(),
      durationMs: durationMs,
    );

    await settingsService.incrementScanCount();
    await historyService.add(result);

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => ResultsScreen(result: result)),
    );
  }

  Future<void> _runAnalysis(int framesCount, int durationMs) async {
    if (!mounted) return;

    setState(() {
      _currentLayer = 'Layer 1: Provenance';
      _progress = 2;
    });
    await Future.delayed(const Duration(milliseconds: 700));

    if (!mounted) return;
    setState(() {
      _currentLayer = 'Layer 2: Visual Artifacts';
      _progress = 3;
    });
    await Future.delayed(const Duration(milliseconds: 800));

    if (!mounted) return;
    setState(() {
      _currentLayer = 'Layer 3: Deep Learning';
      _progress = 4;
    });
    await Future.delayed(const Duration(milliseconds: 800));

    if (!mounted) return;
    setState(() {
      _currentLayer = 'Layer 4: Contextual';
      _progress = 5;
    });
    await Future.delayed(const Duration(milliseconds: 600));

    if (!mounted) return;
    setState(() {
      _currentLayer = 'Generating verdict...';
      _progress = 6;
    });

    final result = await _detectionService.analyzeDemo(
      frameCount: framesCount,
      durationMs: durationMs,
    );

    // Save to history
    await settingsService.incrementScanCount();
    await historyService.add(result);

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => ResultsScreen(result: result)),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _captureService.stopCapture();
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
                    onPressed: () {
                      _captureService.stopCapture();
                      Navigator.of(context).pop();
                    },
                  ),
                  const Spacer(),
                  const Text(
                    'Scanning',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                  const Spacer(),
                  const SizedBox(width: 48),
                ],
              ),

              const Spacer(),

              // Animated circle
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
                          color: Color(0xFF6366F1).withOpacity(0.3 + _pulseController.value * 0.3),
                          blurRadius: 20 + _pulseController.value * 20,
                          spreadRadius: 2 + _pulseController.value * 5,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _errorMessage != null ? Icons.error_outline : Icons.document_scanner_outlined,
                            size: 48,
                            color: Colors.white,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${_progress > 5 ? 4 : _progress} / 4',
                            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 40),

              Text(
                _errorMessage ?? _currentLayer,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: _errorMessage != null ? const Color(0xFFEF4444) : Colors.white,
                ),
              ),

              const SizedBox(height: 8),

              // Progress dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (index) {
                  final isActive = index < _progress - 1 || _progress > 5;
                  final isCurrent = index == _progress - 1 && _progress <= 5;
                  return Container(
                    width: isCurrent ? 24 : 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: isActive ? const Color(0xFF6366F1) : Colors.white.withOpacity(0.2),
                    ),
                  );
                }),
              ),

              const SizedBox(height: 16),

              // Frame counter
              if (_capturedFrames > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A2E),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$_capturedFrames frames captured',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ),

              const Spacer(),

              // Log viewer
              if (_logLines.isNotEmpty)
                Container(
                  height: 60,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A0A14),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: ListView(
                    reverse: true,
                    children: _logLines.reversed
                        .map((l) => Text(l, style: const TextStyle(color: Colors.white38, fontSize: 10, fontFamily: 'monospace')))
                        .toList(),
                  ),
                ),

              const SizedBox(height: 16),

              TextButton(
                onPressed: () {
                  _captureService.stopCapture();
                  Navigator.of(context).pop();
                },
                child: const Text('Cancel', style: TextStyle(color: Colors.white38)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
