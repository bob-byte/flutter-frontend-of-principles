import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../core/storage/local_db.dart';
import '../core/storage/task_db.dart';
import '../core/theme/task_theme_palette.dart';
import '../core/utils/date_helpers.dart';
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

  Future<List<Task>> getTasks({bool? isDone}) async {
    if (_useWebStorage) {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_tasksPrefsKey);
      if (raw == null) return [];
      final list = jsonDecode(raw) as List<dynamic>;
      var tasks = list
          .map((e) => Task.fromMap(Map<String, Object?>.from(e as Map)))
          .toList();
      if (isDone != null) {
        tasks = tasks.where((t) => t.isDone == isDone).toList();
      }
      tasks.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return tasks;
    }

    final database = await _database;
    final where = <String>[];
    final args = <Object?>[];
    if (localDb != null) {
      where.add('(isDeleted = 0 OR isDeleted IS NULL)');
    }
    if (isDone != null) {
      where.add('isDone = ?');
      args.add(isDone ? 1 : 0);
    }
    final rows = await database.query(
      'tasks',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'createdAt DESC',
    );
    final ids = [for (final row in rows) row['id'] as String];
    final grouped = await _loadSubtasksGrouped(database, taskIds: ids);
    return [
      for (final row in rows)
        _taskFromRow(row, grouped[row['id'] as String] ?? const []),
    ];
  }

  /// Incomplete tasks plus completed ones that still matter for Today / calendar.
  Future<List<Task>> getSessionTasks({
    required DateTime rangeStart,
    required DateTime rangeEnd,
    required DateTime today,
  }) async {
    if (_useWebStorage) {
      final all = await getTasks();
      final start = dateOnly(rangeStart);
      final end = dateOnly(rangeEnd);
      final day = dateOnly(today);
      return [
        for (final task in all)
          if (!task.isDone ||
              _taskOverlapsRange(task, start, end) ||
              _completedOnDay(task, day))
            task,
      ];
    }

    final database = await _database;
    final startKey = dateOnly(rangeStart).toIso8601String().substring(0, 10);
    final endKey = dateOnly(rangeEnd).toIso8601String().substring(0, 10);
    final todayKey = dateOnly(today).toIso8601String().substring(0, 10);
    final where = <String>[
      if (localDb != null) '(isDeleted = 0 OR isDeleted IS NULL)',
      '''(
        isDone = 0
        OR (
          dueDate IS NOT NULL
          AND substr(dueDate, 1, 10) <= ?
          AND substr(COALESCE(endDate, dueDate), 1, 10) >= ?
        )
        OR (
          completedAt IS NOT NULL
          AND substr(completedAt, 1, 10) = ?
        )
      )''',
    ];
    final rows = await database.query(
      'tasks',
      where: where.join(' AND '),
      whereArgs: [endKey, startKey, todayKey],
      orderBy: 'createdAt DESC',
    );
    final ids = [for (final row in rows) row['id'] as String];
    final grouped = await _loadSubtasksGrouped(database, taskIds: ids);
    return [
      for (final row in rows)
        _taskFromRow(row, grouped[row['id'] as String] ?? const []),
    ];
  }

  static bool _taskOverlapsRange(Task task, DateTime start, DateTime end) {
    final due = task.dueDate;
    if (due == null) return false;
    final from = dateOnly(due);
    var to = task.endDate == null ? from : dateOnly(task.endDate!);
    if (to.isBefore(from)) to = from;
    return !to.isBefore(start) && !from.isAfter(end);
  }

  static bool _completedOnDay(Task task, DateTime day) {
    if (!task.isDone) return false;
    final doneAt = task.completedAt;
    if (doneAt != null) return isSameDay(doneAt, day);
    return task.dueDate != null && isSameDay(task.dueDate, day);
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
    List<String>? taskIds,
  }) async {
    if (taskIds != null && taskIds.isEmpty) return {};
    String? where;
    List<Object?>? whereArgs;
    if (taskId != null) {
      where = 'taskId = ?';
      whereArgs = [taskId];
    } else if (taskIds != null) {
      where = 'taskId IN (${List.filled(taskIds.length, '?').join(',')})';
      whereArgs = taskIds;
    }
    final rows = await database.query(
      'task_subtasks',
      where: where,
      whereArgs: whereArgs,
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

  /// Deletes every local row for [serverId] (by `serverId` or string `id`).
  ///
  /// When [exceptId] is set, that local row is kept (used after merge upsert).
  Future<void> deleteTasksByServerId(int serverId, {String? exceptId}) async {
    if (serverId == 0) return;
    if (_useWebStorage) {
      final tasks = await getTasks()
        ..removeWhere((t) {
          if (exceptId != null && t.id == exceptId) return false;
          final id = t.serverId ?? int.tryParse(t.id) ?? 0;
          return id == serverId;
        });
      await _persistWebTasks(tasks);
      return;
    }

    final database = await _database;
    final where = StringBuffer('(serverId = ? OR id = ?)');
    final args = <Object?>[serverId, '$serverId'];
    if (exceptId != null) {
      where.write(' AND id != ?');
      args.add(exceptId);
    }
    final rows = await database.query(
      'tasks',
      columns: ['id'],
      where: where.toString(),
      whereArgs: args,
    );
    if (rows.isEmpty) return;
    await database.transaction((txn) async {
      for (final row in rows) {
        final id = row['id'] as String;
        await txn.delete('task_subtasks', where: 'taskId = ?', whereArgs: [id]);
        await txn.delete('tasks', where: 'id = ?', whereArgs: [id]);
      }
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
