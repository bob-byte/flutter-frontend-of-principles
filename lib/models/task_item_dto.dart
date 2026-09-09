import '../core/utils/date_helpers.dart';
import 'schedule_reminder_offset.dart';
import 'task.dart';
import 'task_priority.dart';
import 'task_repeat_config.dart';
import 'task_subtask.dart';

/// DTO бекенду (`SET.WebAPI.Models.TaskItemDto`).
class TaskItemDto {
  const TaskItemDto({
    required this.id,
    required this.name,
    this.notes,
    this.date,
    this.time,
    this.endDate,
    this.endTime,
    this.allDay = false,
    this.isCompleted = false,
    this.constantReminder = false,
    this.reminders = const [],
    this.repeat,
    this.constantNotificationRequestId,
    this.subtasks,
  });

  final int id;
  final String name;
  final String? notes;
  final String? date;
  final String? time;
  final String? endDate;
  final String? endTime;
  final bool allDay;
  final bool isCompleted;
  final bool constantReminder;
  final List<ScheduleReminderOffset> reminders;
  final TaskRepeatConfig? repeat;
  final int? constantNotificationRequestId;

  /// Null means the payload omitted checklists (keep local on merge).
  final List<TaskSubtask>? subtasks;

  factory TaskItemDto.fromJson(Map<String, dynamic> json) {
    final remindersRaw = json['reminders'] ?? json['Reminders'];
    final reminders = <ScheduleReminderOffset>[];
    if (remindersRaw is List) {
      for (final e in remindersRaw) {
        if (e is Map) {
          reminders.add(
            ScheduleReminderOffset.fromJson(Map<String, dynamic>.from(e)),
          );
        }
      }
    }

    final repeatRaw = json['repeat'] ?? json['Repeat'];
    TaskRepeatConfig? repeat;
    if (repeatRaw is Map) {
      repeat = TaskRepeatConfig.fromJson(Map<String, dynamic>.from(repeatRaw));
    } else if (repeatRaw is String && repeatRaw.isNotEmpty) {
      // handled if backend sends JSON string — ignore here
    }

    return TaskItemDto(
      id: _readInt(json['id'] ?? json['Id']) ?? 0,
      name: '${json['name'] ?? json['Name'] ?? ''}',
      notes: _readString(json['notes'] ?? json['Notes']),
      date: _readDate(json['date'] ?? json['Date']),
      time: _readTime(json['time'] ?? json['Time']),
      endDate: _readDate(json['endDate'] ?? json['EndDate']),
      endTime: _readTime(json['endTime'] ?? json['EndTime']),
      allDay: json['allDay'] == true || json['AllDay'] == true,
      isCompleted: json['isCompleted'] == true || json['IsCompleted'] == true,
      constantReminder:
          json['constantReminder'] == true || json['ConstantReminder'] == true,
      reminders: reminders,
      repeat: repeat,
      constantNotificationRequestId: _readInt(
        json['constantNotificationRequestId'] ??
            json['ConstantNotificationRequestId'],
      ),
      subtasks: json.containsKey('subtasks') || json.containsKey('Subtasks')
          ? TaskSubtask.listFromJson(json['subtasks'] ?? json['Subtasks'])
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    if (id > 0) 'id': id,
    'name': name,
    'notes': notes,
    'date': date,
    'time': time,
    'endDate': endDate,
    'endTime': endTime,
    'allDay': allDay,
    'isCompleted': isCompleted,
    'constantReminder': constantReminder,
    'reminders': reminders.map((e) => e.toJson()).toList(),
    if (repeat != null && !repeat!.isNone) 'repeat': repeat!.toJson(),
    if (constantNotificationRequestId != null)
      'constantNotificationRequestId': constantNotificationRequestId,
    if (subtasks != null) 'subtasks': subtasks!.map((e) => e.toJson()).toList(),
  };

  static TaskItemDto fromTask(Task task) {
    String? date;
    String? time;
    if (task.dueDate != null) {
      final due = task.dueDate!;
      date =
          '${due.year.toString().padLeft(4, '0')}-${due.month.toString().padLeft(2, '0')}-${due.day.toString().padLeft(2, '0')}';
      final hasClock = due.hour != 0 || due.minute != 0 || due.second != 0;
      if (!task.allDay && (hasClock || task.reminders.isNotEmpty)) {
        time =
            '${due.hour.toString().padLeft(2, '0')}:${due.minute.toString().padLeft(2, '0')}:00';
      }
    }

    String? endDate;
    String? endTime;
    if (task.endDate != null) {
      final end = task.endDate!;
      endDate =
          '${end.year.toString().padLeft(4, '0')}-${end.month.toString().padLeft(2, '0')}-${end.day.toString().padLeft(2, '0')}';
      if (!task.allDay) {
        endTime =
            '${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}:00';
      }
    }

    return TaskItemDto(
      id: task.serverId ?? int.tryParse(task.id) ?? 0,
      name: task.title,
      notes: task.description.isEmpty ? null : task.description,
      date: date,
      time: time,
      endDate: endDate,
      endTime: endTime,
      allDay: task.allDay,
      isCompleted: task.isDone,
      constantReminder: task.constantReminder,
      reminders: task.reminders,
      repeat: task.repeat.isNone ? null : task.repeat,
      constantNotificationRequestId: task.constantNotificationRequestId,
      subtasks: task.subtasks,
    );
  }

  Task toTask({
    TaskPriority? priority,
    String? theme,
    DateTime? completedAt,
    List<TaskSubtask>? subtasks,
  }) {
    DateTime? dueDate;
    if (date != null) {
      dueDate = DateTime.parse(date!);
      if (time != null && !allDay) {
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
      } else {
        dueDate = dateOnly(dueDate);
      }
    }

    DateTime? end;
    if (endDate != null) {
      end = DateTime.parse(endDate!);
      if (endTime != null && !allDay) {
        final parts = endTime!.split(':');
        if (parts.length >= 2) {
          end = DateTime(
            end.year,
            end.month,
            end.day,
            int.parse(parts[0]),
            int.parse(parts[1]),
            parts.length > 2 ? int.parse(parts[2]) : 0,
          );
        }
      } else {
        end = dateOnly(end);
      }
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
      endDate: end,
      allDay: allDay,
      reminders: reminders,
      constantReminder: constantReminder,
      repeat: repeat ?? const TaskRepeatConfig(),
      constantNotificationRequestId: constantNotificationRequestId,
      completedAt: isCompleted ? completedAt : null,
      subtasks: subtasks ?? this.subtasks ?? const [],
    );
  }
}

int? _readInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

String? _readString(dynamic value) {
  if (value == null) return null;
  final text = value.toString();
  return text.isEmpty ? null : text;
}

String? _readDate(dynamic value) {
  if (value == null) return null;
  if (value is String) return value;
  if (value is DateTime) {
    return '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }
  if (value is Map) {
    final map = Map<dynamic, dynamic>.from(value);
    final year = _readInt(map['year'] ?? map['Year']);
    final month = _readInt(map['month'] ?? map['Month']);
    final day = _readInt(map['day'] ?? map['Day']);
    if (year != null && month != null && day != null) {
      return '${year.toString().padLeft(4, '0')}-'
          '${month.toString().padLeft(2, '0')}-'
          '${day.toString().padLeft(2, '0')}';
    }
  }
  return value.toString();
}

String? _readTime(dynamic value) {
  if (value == null) return null;
  if (value is String) return value;
  if (value is Map) {
    final map = Map<dynamic, dynamic>.from(value);
    final hour = _readInt(map['hour'] ?? map['Hour']) ?? 0;
    final minute = _readInt(map['minute'] ?? map['Minute']) ?? 0;
    final second = _readInt(map['second'] ?? map['Second']) ?? 0;
    return '${hour.toString().padLeft(2, '0')}:'
        '${minute.toString().padLeft(2, '0')}:'
        '${second.toString().padLeft(2, '0')}';
  }
  return value.toString();
}
