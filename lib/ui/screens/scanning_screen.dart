import 'package:flutter/material.dart';
import '../../services/api_service.dart';
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
  final ApiService _apiService = ApiService();
  String _currentLayer = 'Initializing...';
  int _progress = 0;
  bool _isPaused = false;

  // Simulated layer progress
  final List<_LayerInfo> _layers = const [
    _LayerInfo('Provenance', 'Checking metadata...', 1),
    _LayerInfo('Visual Artifacts', 'Analyzing frames...', 2),
    _LayerInfo('Deep Learning', 'ML classification...', 3),
    _LayerInfo('Contextual', 'Cross-referencing...', 4),
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
    for (var layer in _layers) {
      if (_isPaused) {
        await _waitWhilePaused();
      }
      setState(() {
        _currentLayer = layer.label;
        _progress = layer.index;
      });
      // Simulate analysis time per layer
      await Future.delayed(Duration(milliseconds: 800 + layer.index * 400));
    }

    // Finish
    setState(() => _progress = 4);

    // Get result (simulated for now)
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ResultsScreen(
          result: ScanResult(
            id: 'sim_001',
            verdict: 'ai_generated',
            confidence: 87,
            layers: LayerScores(
              provenance: LayerScore(flagged: false, score: 12),
              visual: LayerScore(flagged: true, score: 94, details: [
                'Facial landmark anomalies detected',
                'Temporal frame inconsistencies found',
              ]),
              deepLearning: LayerScore(flagged: true, score: 81),
              contextual: LayerScore(flagged: false, score: 8),
            ),
            scannedAt: DateTime.now(),
            processingTimeMs: 2450,
          ),
        ),
      ),
    );
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
                  const SizedBox(width: 48), // balance the close button
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
                          color: const Color(0xFF6366F1)
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

              // Current layer label
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
                  padding:
 const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
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

              // Cancel button
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
