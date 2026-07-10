import '../core/utils/date_helpers.dart';
import 'task.dart';
import 'task_priority.dart';

/// DTO бекенду (`SET.WebAPI.Models.TaskItemDto`).
class TaskItemDto {
  const TaskItemDto({
    required this.id,
    required this.name,
    this.notes,
    this.date,
    this.time,
    this.isCompleted = false,
  });

  final int id;
  final String name;
  final String? notes;
  final String? date;
  final String? time;
  final bool isCompleted;

  factory TaskItemDto.fromJson(Map<String, dynamic> json) {
    return TaskItemDto(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      notes: json['notes'] as String?,
      date: json['date'] as String?,
      time: json['time'] as String?,
      isCompleted: json['isCompleted'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        if (id > 0) 'id': id,
        'name': name,
        'notes': notes,
        'date': date,
        'time': time,
        'isCompleted': isCompleted,
      };

  static TaskItemDto fromTask(Task task) {
    String? date;
    String? time;
    if (task.dueDate != null) {
      final due = task.dueDate!;
      date =
          '${due.year.toString().padLeft(4, '0')}-${due.month.toString().padLeft(2, '0')}-${due.day.toString().padLeft(2, '0')}';
      if (due.hour != 0 || due.minute != 0 || due.second != 0) {
        time =
            '${due.hour.toString().padLeft(2, '0')}:${due.minute.toString().padLeft(2, '0')}:${due.second.toString().padLeft(2, '0')}';
      }
    }

    return TaskItemDto(
      id: int.tryParse(task.id) ?? 0,
      name: task.title,
      notes: task.description.isEmpty ? null : task.description,
      date: date,
      time: time,
      isCompleted: task.isDone,
    );
  }

  Task toTask({
    TaskPriority? priority,
    String? theme,
    DateTime? completedAt,
  }) {
    DateTime? dueDate;
    if (date != null) {
      dueDate = DateTime.parse(date!);
      if (time != null) {
        final parts = time!.split(':');
        if (parts.length >= 2) {
          dueDate = DateTime(
            dueDate.year,
            dueDate.month,
            dueDate.day,
            int.parse(parts[0]),
            int.parse(parts[1]),
            parts.length > 2 ? int.parse(parts[2]) : 0,
          );
        }
      }
      dueDate = dateOnly(dueDate);
    }

    return Task(
      id: id.toString(),
      title: name,
      description: notes ?? '',
      isDone: isCompleted,
      priority: priority,
      theme: theme,
      createdAt: dueDate ?? DateTime.now(),
      dueDate: dueDate,
      completedAt: isCompleted ? completedAt : null,
    );
  }
}
