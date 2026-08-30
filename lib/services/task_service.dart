import '../core/config/app_config.dart';
import '../core/network/api_client.dart';
import '../core/storage/task_db.dart';
import '../core/theme/task_theme_palette.dart';
import '../models/task.dart';
import 'local_task_storage.dart';
import 'remote_task_storage.dart';

/// Фасад завдань: локальна БД або сервер — залежно від [AppConfig.useLocalData].
class TaskService {
  TaskService({
    required ApiClient apiClient,
    required TaskDb? taskDb,
  })  : _local = LocalTaskStorage(taskDb),
        _remote = RemoteTaskStorage(apiClient);

  final LocalTaskStorage _local;
  final RemoteTaskStorage _remote;

  Future<List<Task>> getTasks() => _active.getTasks();

  Future<Task?> getTask(String id) => _active.getTask(id);

  Future<void> saveTask(Task task, {required bool isNew}) async {
    if (AppConfig.useLocalData && isNew) {
      final withId = task.id == '0' || task.id.isEmpty
          ? task.copyWith(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
            )
          : task;
      await _local.saveTask(withId, isNew: true);
      return;
    }
    await _active.saveTask(task, isNew: isNew);
  }

  Future<void> updateTaskStatus(String id, bool isDone) =>
      _active.updateTaskStatus(id, isDone);

  Future<void> deleteTask(String id) => _active.deleteTask(id);

  Future<Map<String, int>> getThemeColors() => _active.getThemeColors();

  Future<void> saveThemeColor(String name, int colorArgb) =>
      _active.saveThemeColor(name, colorArgb);

  Future<void> registerTheme(String? theme, int? colorArgb) =>
      _active.registerTheme(theme, colorArgb);

  Future<TasksUiTheme> getUiTheme() => _active.getUiTheme();

  Future<void> setUiTheme(TasksUiTheme theme) => _active.setUiTheme(theme);

  dynamic get _active => AppConfig.useLocalData ? _local : _remote;
}
