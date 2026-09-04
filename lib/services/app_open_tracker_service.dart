import 'package:shared_preferences/shared_preferences.dart';

import '../core/utils/date_helpers.dart';

/// MAUI [AppOpenTrackerService]: records the last open day and the most
/// recent day the app was not opened, used to reset the habits streak.
class AppOpenTrackerService {
  AppOpenTrackerService();

  static const lastOpenKey = 'LastOpenDate';
  static const lastMissedKey = 'LastMissedDate';

  DateTime? _lastOpenDate;
  DateTime? _lastMissedDate;
  bool _loaded = false;

  DateTime? get lastMissedDate => _lastMissedDate;

  DateTime? get lastOpenDate => _lastOpenDate;

  Future<void> trackAppOpen({DateTime? now}) async {
    await _ensureLoaded();
    final today = dateOnly(now ?? DateTime.now());
    final lastOpen = _lastOpenDate;

    if (lastOpen != null) {
      final daysSince = today.difference(lastOpen).inDays;
      if (daysSince > 1) {
        _lastMissedDate = today.subtract(const Duration(days: 1));
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(lastMissedKey, _formatDate(_lastMissedDate!));
      }
    }

    _lastOpenDate = today;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(lastOpenKey, _formatDate(today));
  }

  Future<DateTime?> getLastMissedDate() async {
    await _ensureLoaded();
    return _lastMissedDate;
  }

  Future<DateTime?> getLastOpenDate() async {
    await _ensureLoaded();
    return _lastOpenDate;
  }

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    _lastOpenDate = _parseDate(prefs.getString(lastOpenKey));
    _lastMissedDate = _parseDate(prefs.getString(lastMissedKey));
    _loaded = true;
  }

  static String _formatDate(DateTime date) {
    final day = dateOnly(date);
    return '${day.year.toString().padLeft(4, '0')}-'
        '${day.month.toString().padLeft(2, '0')}-'
        '${day.day.toString().padLeft(2, '0')}';
  }

  static DateTime? _parseDate(String? stored) {
    if (stored == null || stored.isEmpty) return null;
    final parsed = DateTime.tryParse(stored);
    if (parsed == null) return null;
    return dateOnly(parsed);
  }
}
