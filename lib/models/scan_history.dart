class ScanHistory {
  final List<ScanHistoryItem> items;

  ScanHistory({required this.items});

  factory ScanHistory.fromJson(List<dynamic> json) {
    return ScanHistory(
      items: json.map((item) => ScanHistoryItem.fromJson(item)).toList(),
    );
  }
}

class ScanHistoryItem {
  final String id;
  final String verdict;
  final int confidence;
  final DateTime scannedAt;

  ScanHistoryItem({
    required this.id,
    required this.verdict,
    required this.confidence,
    required this.scannedAt,
  });

  factory ScanHistoryItem.fromJson(Map<String, dynamic> json) {
    return ScanHistoryItem(
      id: json['id'] ?? '',
      verdict: json['verdict'] ?? 'uncertain',
      confidence: json['confidence'] ?? 50,
      scannedAt: DateTime.tryParse(json['scanned_at'] ?? '') ?? DateTime.now(),
    );
  }
}
