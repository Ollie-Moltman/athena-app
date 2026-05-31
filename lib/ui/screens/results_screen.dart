import 'package:flutter/material.dart';
import '../../models/scan_result.dart';

class ResultsScreen extends StatelessWidget {
  final ScanResult result;

  const ResultsScreen({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final isAI = result.verdict == 'ai_generated';
    final badgeColor = isAI ? const Color(0xFFEF4444) : const Color(0xFF10B981);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      body: SafeArea(
        child: SingleChildScrollView(
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
                    'Results',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.share_outlined,
                        color: Colors.white70, size: 20),
                    onPressed: () {
                      // TODO: share result
                    },
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // Verdict badge
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 32),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A2E),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: badgeColor.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    Text(
                      result.verdictEmoji,
                      style: const TextStyle(fontSize: 48),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      result.verdictLabel.toUpperCase(),
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: badgeColor,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${result.confidence}% confidence',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white60,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Processing time
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.timer_outlined,
                      size: 16, color: Colors.white38),
                  const SizedBox(width: 6),
                  Text(
                    'Analyzed in ${(result.processingTimeMs / 1000).toStringAsFixed(1)}s',
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // Layer breakdown
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Detection Breakdown',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              _LayerBar(
                name: 'Provenance',
                score: result.layers.provenance.score,
                flagged: result.layers.provenance.flagged,
                details: result.layers.provenance.details,
              ),
              const SizedBox(height: 12),
              _LayerBar(
                name: 'Visual Artifacts',
                score: result.layers.visual.score,
                flagged: result.layers.visual.flagged,
                details: result.layers.visual.details,
              ),
              const SizedBox(height: 12),
              _LayerBar(
                name: 'Deep Learning',
                score: result.layers.deepLearning.score,
                flagged: result.layers.deepLearning.flagged,
                details: result.layers.deepLearning.details,
              ),
              const SizedBox(height: 12),
              _LayerBar(
                name: 'Contextual',
                score: result.layers.contextual.score,
                flagged: result.layers.contextual.flagged,
                details: result.layers.contextual.details,
              ),

              const SizedBox(height: 32),

              // Done button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Scan Another',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LayerBar extends StatelessWidget {
  final String name;
  final int score;
  final bool flagged;
  final List<String> details;

  const _LayerBar({
    required this.name,
    required this.score,
    required this.flagged,
    this.details = const [],
  });

  @override
  Widget build(BuildContext context) {
    final barColor = flagged ? const Color(0xFFEF4444) : const Color(0xFF10B981);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (flagged)
                const Icon(Icons.warning_amber,
                    size: 16, color: Color(0xFFEF4444)),
              if (flagged) const SizedBox(width: 6),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Text(
                '$score%',
                style: TextStyle(
                  color: barColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: score / 100,
              backgroundColor: Colors.white.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation(barColor),
              minHeight: 6,
            ),
          ),
          if (details.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...details.map(
              (d) => Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ', style: TextStyle(color: Colors.white38)),
                    Expanded(
                      child: Text(
                        d,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
