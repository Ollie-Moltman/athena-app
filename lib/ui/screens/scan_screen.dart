import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/screen_capture_service.dart';
import '../../services/api_service.dart';
import 'scanning_screen.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final ScreenCaptureService _captureService = ScreenCaptureService();
  final ApiService _apiService = ApiService();
  bool _isCapturing = false;

  Future<void> _startScanning() async {
    // Check permission first
    final hasPermission = await _captureService.hasPermission();
    if (!hasPermission) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Screen capture permission required'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    setState(() => _isCapturing = true);

    // Start capture and navigate to scanning screen
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ScanningScreen(),
      ),
    ).then((_) => setState(() => _isCapturing = false));
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
                  IconButton(
                    icon: const Icon(Icons.history, color: Colors.white70),
                    onPressed: () {
                      Navigator.of(context).pushNamed('/history');
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'AI Video Detection',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white38,
                  letterSpacing: 2,
                ),
              ),

              const Spacer(),

              // Main scan button
              GestureDetector(
                onTap: _isCapturing ? null : _startScanning,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6366F1).withOpacity(0.4),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Center(
                    child: _isCapturing
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.play_arrow_rounded,
                                size: 64,
                                color: Colors.white,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'SCAN',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 4,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),

              const Spacer(),

              // Instructions
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A2E),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Column(
                  children: [
                    _InstructionRow(
                      number: '1',
                      text: 'Play any video on your screen',
                    ),
                    SizedBox(height: 12),
                    _InstructionRow(
                      number: '2',
                      text: 'Tap "Scan" to capture 3 seconds',
                    ),
                    SizedBox(height: 12),
                    _InstructionRow(
                      number: '3',
                      text: 'Get AI vs Real verdict instantly',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Settings button
              TextButton.icon(
                onPressed: () {
                  Navigator.of(context).pushNamed('/settings');
                },
                icon: const Icon(Icons.settings_outlined,
                    color: Colors.white38, size: 18),
                label: const Text(
                  'Settings',
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

class _InstructionRow extends StatelessWidget {
  final String number;
  final String text;

  const _InstructionRow({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFF6366F1),
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
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
              fontSize: 15,
            ),
          ),
        ),
      ],
    );
  }
}
