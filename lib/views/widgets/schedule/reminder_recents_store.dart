import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class ReminderRecentsStore {
  static const _key = 'schedule_reminder_recents_v1';
  static const _max = 5;

  static Future<List<int>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => (e as num).toInt()).toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<void> add(int offsetMinutes) async {
    if (offsetMinutes < 0) return;
    final current = await load();
    final next = [
      offsetMinutes,
      ...current.where((e) => e != offsetMinutes),
    ].take(_max).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(next));
  }
}
