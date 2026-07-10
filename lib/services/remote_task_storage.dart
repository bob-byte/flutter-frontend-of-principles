import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../core/theme/task_theme_palette.dart';
import '../models/task.dart';
import '../models/task_item_dto.dart';
import '../models/task_priority.dart';

/// Завдання через REST API (PostgreSQL на сервері).
class RemoteTaskStorage {
  RemoteTaskStorage(this._apiClient);

  final ApiClient _apiClient;

  static const _themesPrefsKey = 'tasks_module_themes_v1';
  static const _uiThemePrefsKey = 'tasks_module_ui_theme_v1';
  static const _metaPrefsKey = 'tasks_module_meta_v1';

  List<Task>? _cache;

  Future<List<Task>> getTasks() async {
    final response = await _apiClient.get('${ApiEndpoints.tasks}/all');
    final list = response.data as List<dynamic>;
    final meta = await _loadLocalMeta();

    final tasks = list
        .map((item) {
          final dto = TaskItemDto.fromJson(
            Map<String, dynamic>.from(item as Map),
          );
          final local = meta[dto.id.toString()];
          return dto.toTask(
            priority: TaskPriority.fromOptionalString(
              local?['priority'] as String?,
            ),
            theme: local?['theme'] as String?,
          );
        })
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    _cache = tasks;
    return tasks;
  }

  Future<Task?> getTask(String id) async {
    final tasks = _cache ?? await getTasks();
    for (final task in tasks) {
      if (task.id == id) return task;
    }
    return null;
  }

  Future<void> saveTask(Task task, {required bool isNew}) async {
    final dto = TaskItemDto.fromTask(task);

    if (isNew) {
      final response = await _apiClient.post(
        ApiEndpoints.tasks,
        data: dto.toJson()..remove('id'),
      );
      final created = TaskItemDto.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
      await _saveLocalMeta(
        created.id.toString(),
        priority: task.priority,
        theme: task.theme,
      );
    } else {
      final serverId = int.parse(task.id);
      await _apiClient.put(
        '${ApiEndpoints.tasks}/$serverId',
        data: dto.toJson(),
      );
      await _saveLocalMeta(
        task.id,
        priority: task.priority,
        theme: task.theme,
        clearPriority: task.priority == null,
        clearTheme: task.theme == null,
      );
    }

    _cache = null;
  }

  Future<void> updateTaskStatus(String id, bool isDone) async {
    final serverId = int.parse(id);
    await _apiClient.put(
      '${ApiEndpoints.tasks}/$serverId/status',
      data: {'isCompleted': isDone},
    );
    _cache = null;
  }

  Future<void> deleteTask(String id) async {
    final serverId = int.parse(id);
    await _apiClient.delete('${ApiEndpoints.tasks}/$serverId');
    await _removeLocalMeta(id);
    _cache = null;
  }

  Future<Map<String, int>> getThemeColors() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_themesPrefsKey);
    if (raw == null) return {};
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return map.map((k, v) => MapEntry(k, v as int));
  }

  Future<void> saveThemeColor(String name, int colorArgb) async {
    final colors = await getThemeColors()..[name] = colorArgb;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themesPrefsKey, jsonEncode(colors));
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

  Future<Map<String, Map<String, dynamic>>> _loadLocalMeta() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_metaPrefsKey);
    if (raw == null) return {};
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return decoded.map(
      (key, value) => MapEntry(key, Map<String, dynamic>.from(value as Map)),
    );
  }

  Future<void> _saveLocalMeta(
    String taskId, {
    TaskPriority? priority,
    String? theme,
    bool clearPriority = false,
    bool clearTheme = false,
  }) async {
    final meta = await _loadLocalMeta();
    final entry = Map<String, dynamic>.from(meta[taskId] ?? {});

    if (clearPriority) {
      entry.remove('priority');
    } else if (priority != null) {
      entry['priority'] = priority.toStorage();
    }

    if (clearTheme) {
      entry.remove('theme');
    } else if (theme != null && theme.isNotEmpty) {
      entry['theme'] = theme;
    }

    if (entry.isEmpty) {
      meta.remove(taskId);
    } else {
      meta[taskId] = entry;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_metaPrefsKey, jsonEncode(meta));
  }

  Future<void> _removeLocalMeta(String taskId) async {
    final meta = await _loadLocalMeta()..remove(taskId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_metaPrefsKey, jsonEncode(meta));
  }
}
