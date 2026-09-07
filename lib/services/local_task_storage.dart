import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../core/storage/local_db.dart';
import '../core/storage/task_db.dart';
import '../core/theme/task_theme_palette.dart';
import '../models/task.dart';
import '../models/task_subtask.dart';

/// Локальне сховище завдань (SQLite / SharedPreferences на web).
class LocalTaskStorage {
  LocalTaskStorage(this._db, {this.localDb});

  final TaskDb? _db;
  final LocalDb? localDb;

  static const _tasksPrefsKey = 'tasks_module_tasks_v1';
  static const _themesPrefsKey = 'tasks_module_themes_v1';
  static const _uiThemePrefsKey = 'tasks_module_ui_theme_v1';

  bool get _useWebStorage => kIsWeb || (_db == null && localDb == null);

  Future<Database> get _database async {
    if (localDb != null) return localDb!.database;
    return _db!.database;
  }

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

    final database = await _database;
    final rows = await database.query(
      'tasks',
      where: localDb != null ? 'isDeleted = 0 OR isDeleted IS NULL' : null,
      orderBy: 'createdAt DESC',
    );
    final grouped = await _loadSubtasksGrouped(database);
    return [
      for (final row in rows)
        _taskFromRow(row, grouped[row['id'] as String] ?? const []),
    ];
  }

  Future<Task?> getTask(String id) async {
    if (_useWebStorage) {
      final tasks = await getTasks();
      for (final task in tasks) {
        if (task.id == id) return task;
      }
      for (final task in tasks) {
        if (task.serverId != null && task.serverId.toString() == id) {
          return task;
        }
      }
      return null;
    }

    final database = await _database;
    final byId = await database.query(
      'tasks',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (byId.isNotEmpty) return _taskFromRowWithChildren(database, byId.first);

    final serverId = int.tryParse(id);
    if (serverId == null) return null;
    final byServer = await database.query(
      'tasks',
      where: 'serverId = ?',
      whereArgs: [serverId],
      limit: 1,
    );
    if (byServer.isEmpty) return null;
    return _taskFromRowWithChildren(database, byServer.first);
  }

  Future<Task?> getTaskByLocalId(int localId) async {
    if (_useWebStorage) {
      final tasks = await getTasks();
      for (final task in tasks) {
        if (task.localId == localId) return task;
      }
      return null;
    }
    final database = await _database;
    final rows = await database.query(
      'tasks',
      where: 'localId = ?',
      whereArgs: [localId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _taskFromRowWithChildren(database, rows.first);
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

    final database = await _database;
    await database.transaction((txn) async {
      await txn.insert(
        'tasks',
        _row(task),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await _replaceSubtasks(txn, task.id, task.subtasks);
    });
  }

  Future<void> replaceTaskId(String oldId, Task task) async {
    if (_useWebStorage) {
      final tasks = await getTasks();
      tasks.removeWhere((t) => t.id == oldId);
      tasks.add(task);
      await _persistWebTasks(tasks);
      return;
    }
    final database = await _database;
    await database.transaction((txn) async {
      await txn.delete(
        'task_subtasks',
        where: 'taskId = ?',
        whereArgs: [oldId],
      );
      await txn.delete('tasks', where: 'id = ?', whereArgs: [oldId]);
      await txn.insert(
        'tasks',
        _row(task),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await _replaceSubtasks(txn, task.id, task.subtasks);
    });
  }

  Map<String, Object?> _row(Task task) {
    final map = Map<String, Object?>.from(task.toMap());
    map.remove('subtasksJson');
    if (localDb == null) {
      map.remove('localId');
      map.remove('serverId');
      map.remove('lastModified');
      map.remove('isDeleted');
    }
    return map;
  }

  Future<Task> _taskFromRowWithChildren(
    DatabaseExecutor database,
    Map<String, Object?> row,
  ) async {
    final taskId = row['id'] as String;
    final grouped = await _loadSubtasksGrouped(database, taskId: taskId);
    return _taskFromRow(row, grouped[taskId] ?? const []);
  }

  Task _taskFromRow(Map<String, Object?> row, List<TaskSubtask> subtasks) {
    return Task.fromMap(row).copyWith(subtasks: subtasks);
  }

  Future<Map<String, List<TaskSubtask>>> _loadSubtasksGrouped(
    DatabaseExecutor database, {
    String? taskId,
  }) async {
    final rows = await database.query(
      'task_subtasks',
      where: taskId == null ? null : 'taskId = ?',
      whereArgs: taskId == null ? null : [taskId],
      orderBy: 'sortOrder ASC',
    );
    final grouped = <String, List<TaskSubtask>>{};
    for (final row in rows) {
      final parentId = row['taskId'] as String;
      grouped
          .putIfAbsent(parentId, () => [])
          .add(
            TaskSubtask(
              id: row['id'] as String,
              title: row['title'] as String? ?? '',
              isDone: (row['isDone'] as int? ?? 0) == 1,
              sortOrder: row['sortOrder'] as int? ?? 0,
            ),
          );
    }
    return grouped;
  }

  Future<void> _replaceSubtasks(
    DatabaseExecutor database,
    String taskId,
    List<TaskSubtask> items,
  ) async {
    await database.delete(
      'task_subtasks',
      where: 'taskId = ?',
      whereArgs: [taskId],
    );
    for (final item in TaskSubtask.sanitize(items)) {
      await database.insert('task_subtasks', {
        'id': item.id,
        'taskId': taskId,
        'title': item.title,
        'isDone': item.isDone ? 1 : 0,
        'sortOrder': item.sortOrder,
      });
    }
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
      final tasks = await getTasks()
        ..removeWhere((t) => t.id == id);
      await _persistWebTasks(tasks);
      return;
    }

    final database = await _database;
    await database.transaction((txn) async {
      await txn.delete('task_subtasks', where: 'taskId = ?', whereArgs: [id]);
      await txn.delete('tasks', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<Map<String, int>> getThemeColors() async {
    if (_useWebStorage) {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_themesPrefsKey);
      if (raw == null) return {};
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return map.map((k, v) => MapEntry(k, v as int));
    }

    final database = await _database;
    final rows = await database.query('task_themes');
    return {
      for (final row in rows) row['name'] as String: row['colorArgb'] as int,
    };
  }

  Future<void> saveThemeColor(String name, int colorArgb) async {
    if (_useWebStorage) {
      final colors = await getThemeColors()
        ..[name] = colorArgb;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themesPrefsKey, jsonEncode(colors));
      return;
    }

    final database = await _database;
    await database.insert('task_themes', {
      'name': name,
      'colorArgb': colorArgb,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
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
