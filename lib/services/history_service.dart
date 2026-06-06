import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/scan_result.dart';

/// Stores the last N scan results locally via SharedPreferences.
/// Oldest entries are evicted when the limit is exceeded.
class HistoryService {
  static const String _KEY = 'scan_history';
  static const int MAX_ITEMS = 10;

  final SharedPreferences _prefs;

  HistoryService(this._prefs);

  /// Load all stored scan results, most recent first.
  List<ScanResult> loadAll() {
    final raw = _prefs.getStringList(_KEY) ?? [];
    return raw
        .map((s) {
          try {
            return ScanResult.fromJson(jsonDecode(s) as Map<String, dynamic>);
          } catch (_) {
            return null;
          }
        })
        .whereType<ScanResult>()
        .toList();
  }

  /// Add a result, evicting oldest if at capacity.
  Future<void> add(ScanResult result) async {
    final list = loadAll();
    list.insert(0, result); // newest first

    // Trim to MAX_ITEMS
    final trimmed = list.take(MAX_ITEMS).toList();

    await _prefs.setStringList(
      _KEY,
      trimmed.map((r) => jsonEncode(_toJson(r))).toList(),
    );
  }

  /// Remove a specific result by id.
  Future<void> remove(String id) async {
    final list = loadAll();
    list.removeWhere((r) => r.id == id);
    await _saveList(list);
  }

  /// Clear all history.
  Future<void> clearAll() async {
    await _prefs.remove(_KEY);
  }

  Future<void> _saveList(List<ScanResult> list) async {
    await _prefs.setStringList(
      _KEY,
      list.map((r) => jsonEncode(_toJson(r))).toList(),
    );
  }

  Map<String, dynamic> _toJson(ScanResult r) => {
    'id': r.id,
    'verdict': r.verdict,
    'confidence': r.confidence,
    'layers': {
      'provenance': {'flagged': r.layers.provenance.flagged, 'score': r.layers.provenance.score, 'details': r.layers.provenance.details},
      'visual': {'flagged': r.layers.visual.flagged, 'score': r.layers.visual.score, 'details': r.layers.visual.details},
      'deep_learning': {'flagged': r.layers.deepLearning.flagged, 'score': r.layers.deepLearning.score, 'details': r.layers.deepLearning.details},
      'contextual': {'flagged': r.layers.contextual.flagged, 'score': r.layers.contextual.score, 'details': r.layers.contextual.details},
    },
    'scanned_at': r.scannedAt.toIso8601String(),
    'processing_time_ms': r.processingTimeMs,
    'thumbnail_base64': r.thumbnailBase64,
  };
}