import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../core/storage/task_db.dart';
import '../core/theme/task_theme_palette.dart';
import '../models/task.dart';

/// Локальне сховище завдань (SQLite / SharedPreferences на web).
class LocalTaskStorage {
  LocalTaskStorage(this._db);

  final TaskDb? _db;

  static const _tasksPrefsKey = 'tasks_module_tasks_v1';
  static const _themesPrefsKey = 'tasks_module_themes_v1';
  static const _uiThemePrefsKey = 'tasks_module_ui_theme_v1';

  bool get _useWebStorage => kIsWeb || _db == null;

  Future<List<Task>> getTasks() async {
    if (_useWebStorage) {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_tasksPrefsKey);
      if (raw == null) return [];
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => Task.fromMap(Map<String, Object?>.from(e as Map)))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }

    final database = await _db!.database;
    final rows = await database.query('tasks', orderBy: 'createdAt DESC');
    return rows.map(Task.fromMap).toList();
  }

  Future<Task?> getTask(String id) async {
    final tasks = await getTasks();
    for (final task in tasks) {
      if (task.id == id) return task;
    }
    return null;
  }

  Future<void> saveTask(Task task, {required bool isNew}) async {
    if (_useWebStorage) {
      final tasks = await getTasks();
      final index = tasks.indexWhere((t) => t.id == task.id);
      if (index >= 0) {
        tasks[index] = task;
      } else {
        tasks.add(task);
      }
      await _persistWebTasks(tasks);
      return;
    }

    final database = await _db!.database;
    await database.insert(
      'tasks',
      task.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateTaskStatus(String id, bool isDone) async {
    final task = await getTask(id);
    if (task == null) return;

    await saveTask(
      task.copyWith(
        isDone: isDone,
        completedAt: isDone ? DateTime.now() : null,
        clearCompletedAt: !isDone,
      ),
      isNew: false,
    );
  }

  Future<void> deleteTask(String id) async {
    if (_useWebStorage) {
      final tasks = await getTasks()..removeWhere((t) => t.id == id);
      await _persistWebTasks(tasks);
      return;
    }

    final database = await _db!.database;
    await database.delete('tasks', where: 'id = ?', whereArgs: [id]);
  }

  Future<Map<String, int>> getThemeColors() async {
    if (_useWebStorage) {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_themesPrefsKey);
      if (raw == null) return {};
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return map.map((k, v) => MapEntry(k, v as int));
    }

    final database = await _db!.database;
    final rows = await database.query('task_themes');
    return {
      for (final row in rows)
        row['name'] as String: row['colorArgb'] as int,
    };
  }

  Future<void> saveThemeColor(String name, int colorArgb) async {
    if (_useWebStorage) {
      final colors = await getThemeColors()..[name] = colorArgb;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themesPrefsKey, jsonEncode(colors));
      return;
    }

    final database = await _db!.database;
    await database.insert(
      'task_themes',
      {'name': name, 'colorArgb': colorArgb},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> registerTheme(String? theme, int? colorArgb) async {
    final trimmed = theme?.trim();
    if (trimmed == null || trimmed.isEmpty) return;

    final colors = await getThemeColors();
    if (colorArgb != null) {
      await saveThemeColor(trimmed, colorArgb);
    } else if (!colors.containsKey(trimmed)) {
      final index = colors.length % taskCategoryPalette.length;
      await saveThemeColor(trimmed, taskCategoryPalette[index].toARGB32());
    }
  }

  Future<TasksUiTheme> getUiTheme() async {
    final prefs = await SharedPreferences.getInstance();
    return TasksUiTheme.fromStorage(prefs.getString(_uiThemePrefsKey));
  }

  Future<void> setUiTheme(TasksUiTheme theme) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_uiThemePrefsKey, theme.storageKey);
  }

  Future<void> _persistWebTasks(List<Task> tasks) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(tasks.map((t) => t.toMap()).toList());
    await prefs.setString(_tasksPrefsKey, encoded);
  }
}
