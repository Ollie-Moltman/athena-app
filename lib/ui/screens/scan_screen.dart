import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:athena/main.dart';
import 'scanning_screen.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  bool _isCapturing = false;

  static const MethodChannel _channel = MethodChannel('com.athena.app/capture');

  Future<void> _startScanning() async {
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

    try {
      final granted = await _channel.invokeMethod<bool>('startCapture', {
        'max_duration_ms': settingsService.maxDurationMs,
      });

      if (!mounted) return;

      if (granted == true) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const ScanningScreen(permissionGranted: true),
          ),
        ).then((_) => setState(() => _isCapturing = false));
      } else {
        setState(() => _isCapturing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Screen capture permission required'),
            backgroundColor: Color(0xFFEF4444),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } on PlatformException catch (_) {
      if (!mounted) return;
      setState(() => _isCapturing = false);
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const ScanningScreen(permissionGranted: false),
        ),
      ).then((_) => setState(() => _isCapturing = false));
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
                        icon: const Icon(Icons.history, color: Colors.white70),
                        onPressed: () => Navigator.of(context).pushNamed('/history'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'AI Video Detection · ${settingsService.maxDurationLabel}',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.white38,
                  letterSpacing: 2,
                ),
              ),

              const Spacer(),

              // Scan button
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
                              Icon(Icons.play_arrow_rounded, size: 64, color: Colors.white),
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
                    _InstructionRow(number: '1', text: 'Play any video on your screen'),
                    SizedBox(height: 12),
                    _InstructionRow(number: '2', text: 'Tap scan to capture & scan'),
                    SizedBox(height: 12),
                    _InstructionRow(number: '3', text: 'Get AI vs Real verdict instantly'),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              TextButton.icon(
                onPressed: () => Navigator.of(context).pushNamed('/settings'),
                icon: const Icon(Icons.settings_outlined, color: Colors.white38, size: 18),
                label: const Text('Settings', style: TextStyle(color: Colors.white38)),
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
          decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF6366F1)),
          child: Center(child: Text(number, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 15))),
      ],
    );
  }
}