import 'package:shared_preferences/shared_preferences.dart';

/// Persisted app settings backed by SharedPreferences.
/// All settings default to sensible values for a new user.
class SettingsService {
  static const String _KEY_MAX_DURATION = 'max_scan_duration_ms';
  static const String _KEY_QUALITY = 'capture_quality';
  static const String _KEY_SCAN_COUNT = 'scan_count_today';
  static const String _KEY_SCAN_DATE = 'scan_count_date';

  static const int DEFAULT_MAX_DURATION_MS = 20000; // 20 seconds
  static const String DEFAULT_QUALITY = '1080p';

  final SharedPreferences _prefs;

  SettingsService(this._prefs);

  // ── Max Scan Duration ──────────────────────────────────────────────────────
  /// Duration in milliseconds. Defaults to 20 seconds.
  int get maxDurationMs => _prefs.getInt(_KEY_MAX_DURATION) ?? DEFAULT_MAX_DURATION_MS;

  Future<void> setMaxDurationMs(int ms) async {
    await _prefs.setInt(_KEY_MAX_DURATION, ms);
  }

  String get maxDurationLabel {
    final s = maxDurationMs ~/ 1000;
    return '$s seconds';
  }

  // ── Capture Quality ────────────────────────────────────────────────────────
  /// '720p', '1080p', or '4k'. Defaults to 1080p.
  String get quality => _prefs.getString(_KEY_QUALITY) ?? DEFAULT_QUALITY;

  Future<void> setQuality(String q) async {
    await _prefs.setString(_KEY_QUALITY, q);
  }

  String get qualityLabel {
    switch (quality) {
      case '720p':  return '720p (Faster)';
      case '4k':    return '4K (Slower)';
      default:      return '1080p (Recommended)';
    }
  }

  // ── Daily scan counter ─────────────────────────────────────────────────────
  /// Returns scans used today, resetting if the day has changed.
  int get scansUsedToday {
    final date = _prefs.getString(_KEY_SCAN_DATE);
    final today = _today();
    if (date != today) {
      // Reset for new day
      _prefs.setString(_KEY_SCAN_DATE, today);
      _prefs.setInt(_KEY_SCAN_COUNT, 0);
      return 0;
    }
    return _prefs.getInt(_KEY_SCAN_COUNT) ?? 0;
  }

  int get scansRemaining => (5 - scansUsedToday).clamp(0, 5);

  Future<void> incrementScanCount() async {
    final today = _today();
    final storedDate = _prefs.getString(_KEY_SCAN_DATE);
    if (storedDate != today) {
      // New day — reset
      await _prefs.setString(_KEY_SCAN_DATE, today);
      await _prefs.setInt(_KEY_SCAN_COUNT, 1);
    } else {
      await _prefs.setInt(_KEY_SCAN_COUNT, scansUsedToday + 1);
    }
  }

  String _today() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2,'0')}-${now.day.toString().padLeft(2,'0')}';
  }

  // ── Reset all settings ─────────────────────────────────────────────────────
  Future<void> resetAll() async {
    await _prefs.remove(_KEY_MAX_DURATION);
    await _prefs.remove(_KEY_QUALITY);
    await _prefs.remove(_KEY_SCAN_COUNT);
    await _prefs.remove(_KEY_SCAN_DATE);
  }
}