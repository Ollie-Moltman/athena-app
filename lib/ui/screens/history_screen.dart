import 'dart:convert';
import 'package:flutter/material.dart';
import '../../models/scan_result.dart';
import 'results_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  // History stored locally on-device (shared_preferences or sqflite in production)
  List<ScanResult> _history = [];
  bool _isLoading = false;


  @override
  void initState() {
    super.initState();
    // In production: load from SharedPreferences or SQLite
    _isLoading = false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F1A),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'History',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        actions: [
          if (_history.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  color: Colors.white38, size: 20),
              onPressed: () {
                // TODO: confirm and clear history
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF6366F1)),
            )
          : _history.isEmpty
              ? _EmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _history.length,
                  itemBuilder: (context, index) {
                    final item = _history[index];
                    return _HistoryCard(
                      result: item,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ResultsScreen(result: item),
                          ),
                        );
                      },
                    );
                  },
                ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.history,
            size: 64,
            color: Colors.white.withOpacity(0.1),
          ),
          const SizedBox(height: 16),
          const Text(
            'No scans yet',
            style: TextStyle(
              color: Colors.white38,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your scan history will appear here',
            style: TextStyle(
              color: Colors.white24,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final ScanResult result;
  final VoidCallback onTap;

  const _HistoryCard({required this.result, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isAI = result.verdict == 'ai_generated';
    final badgeColor = isAI ? const Color(0xFFEF4444) : const Color(0xFF10B981);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // Thumbnail placeholder
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFF0F0F1A),
                borderRadius: BorderRadius.circular(8),
              ),
              child: result.thumbnailBase64 != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        base64Decode(result.thumbnailBase64!),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox(),
                      ),
                    )
                  : const Icon(
                      Icons.videocam_outlined,
                      color: Colors.white24,
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.verdictLabel,
                    style: TextStyle(
                      color: badgeColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${result.confidence}% confidence',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatDate(result.scannedAt),
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Icon(
                  Icons.chevron_right,
                  color: Colors.white.withOpacity(0.2),
                  size: 20,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
