class ScanResult {
  final String id;
  final String verdict; // 'ai_generated' | 'real' | 'uncertain'
  final int confidence; // 0-100
  final LayerScores layers;
  final DateTime scannedAt;
  final int processingTimeMs;
  final String? thumbnailBase64;

  ScanResult({
    required this.id,
    required this.verdict,
    required this.confidence,
    required this.layers,
    required this.scannedAt,
    required this.processingTimeMs,
    this.thumbnailBase64,
  });

  factory ScanResult.fromJson(Map<String, dynamic> json) {
    return ScanResult(
      id: json['id'] ?? '',
      verdict: json['verdict'] ?? 'uncertain',
      confidence: json['confidence'] ?? 50,
      layers: LayerScores.fromJson(json['layers'] ?? {}),
      scannedAt: DateTime.tryParse(json['scanned_at'] ?? '') ?? DateTime.now(),
      processingTimeMs: json['processing_time_ms'] ?? 0,
      thumbnailBase64: json['thumbnail_base64'],
    );
  }

  String get verdictLabel {
    switch (verdict) {
      case 'ai_generated':
        return 'AI-Generated';
      case 'real':
        return 'Real';
      default:
        return 'Uncertain';
    }
  }

  String get verdictEmoji {
    switch (verdict) {
      case 'ai_generated':
        return '⚠️';
      case 'real':
        return '✅';
      default:
        return '🤔';
    }
  }
}

class LayerScores {
  final LayerScore provenance;
  final LayerScore visual;
  final LayerScore deepLearning;
  final LayerScore contextual;

  LayerScores({
    required this.provenance,
    required this.visual,
    required this.deepLearning,
    required this.contextual,
  });

  factory LayerScores.fromJson(Map<String, dynamic> json) {
    return LayerScores(
      provenance: LayerScore.fromJson(json['provenance'] ?? {}),
      visual: LayerScore.fromJson(json['visual'] ?? {}),
      deepLearning: LayerScore.fromJson(json['deep_learning'] ?? {}),
      contextual: LayerScore.fromJson(json['contextual'] ?? {}),
    );
  }
}

class LayerScore {
  final bool flagged;
  final int score; // 0-100
  final List<String> details;

  LayerScore({
    required this.flagged,
    required this.score,
    this.details = const [],
  });

  factory LayerScore.fromJson(Map<String, dynamic> json) {
    return LayerScore(
      flagged: json['flagged'] ?? false,
      score: json['score'] ?? 0,
      details: List<String>.from(json['details'] ?? []),
    );
  }
}
