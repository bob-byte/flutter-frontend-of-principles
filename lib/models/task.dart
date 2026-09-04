import 'dart:convert';

import 'schedule_reminder_offset.dart';
import 'task_priority.dart';
import 'task_repeat_config.dart';

class Task {
  const Task({
    required this.id,
    required this.title,
    this.description = '',
    this.isDone = false,
    this.theme,
    this.priority,
    required this.createdAt,
    this.dueDate,
    this.endDate,
    this.allDay = false,
    this.reminders = const [],
    this.constantReminder = false,
    this.repeat = const TaskRepeatConfig(),
    this.constantNotificationRequestId,
    this.completedAt,
    this.localId,
    this.serverId,
    this.lastModified,
    this.isDeleted = false,
  });

  final String id;
  final String title;
  final String description;
  final bool isDone;
  final String? theme;
  final TaskPriority? priority;
  final DateTime createdAt;

  /// Start date/time (date-only when [allDay] or time unset at midnight meaning TBD).
  final DateTime? dueDate;

  /// End date/time for Duration mode; null means Date-only schedule.
  final DateTime? endDate;
  final bool allDay;
  final List<ScheduleReminderOffset> reminders;
  final bool constantReminder;
  final TaskRepeatConfig repeat;
  final int? constantNotificationRequestId;
  final DateTime? completedAt;
  final int? localId;
  final int? serverId;
  final DateTime? lastModified;
  final bool isDeleted;

  bool get hasSchedule => dueDate != null;
  bool get hasDuration => endDate != null;

  Task copyWith({
    String? id,
    String? title,
    String? description,
    bool? isDone,
    String? theme,
    bool clearTheme = false,
    TaskPriority? priority,
    bool clearPriority = false,
    DateTime? createdAt,
    DateTime? dueDate,
    bool clearDueDate = false,
    DateTime? endDate,
    bool clearEndDate = false,
    bool? allDay,
    List<ScheduleReminderOffset>? reminders,
    bool? constantReminder,
    TaskRepeatConfig? repeat,
    int? constantNotificationRequestId,
    bool clearConstantNotificationRequestId = false,
    DateTime? completedAt,
    bool clearCompletedAt = false,
    int? localId,
    int? serverId,
    DateTime? lastModified,
    bool? isDeleted,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      isDone: isDone ?? this.isDone,
      theme: clearTheme ? null : (theme ?? this.theme),
      priority: clearPriority ? null : (priority ?? this.priority),
      createdAt: createdAt ?? this.createdAt,
      dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
      allDay: allDay ?? this.allDay,
      reminders: reminders ?? this.reminders,
      constantReminder: constantReminder ?? this.constantReminder,
      repeat: repeat ?? this.repeat,
      constantNotificationRequestId: clearConstantNotificationRequestId
          ? null
          : (constantNotificationRequestId ?? this.constantNotificationRequestId),
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
      localId: localId ?? this.localId,
      serverId: serverId ?? this.serverId,
      lastModified: lastModified ?? this.lastModified,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  /// Clears all schedule fields (date, duration, reminders, repeat, constant).
  Task clearedSchedule() {
    return copyWith(
      clearDueDate: true,
      clearEndDate: true,
      allDay: false,
      reminders: const [],
      constantReminder: false,
      repeat: const TaskRepeatConfig(),
      clearConstantNotificationRequestId: true,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'title': title,
        'description': description,
        'isDone': isDone ? 1 : 0,
        'theme': theme,
        'priority': priority?.toStorage() ?? 'none',
        'createdAt': createdAt.toIso8601String(),
        'dueDate': dueDate?.toIso8601String(),
        'endDate': endDate?.toIso8601String(),
        'allDay': allDay ? 1 : 0,
        'remindersJson': jsonEncode(reminders.map((e) => e.toJson()).toList()),
        'constantReminder': constantReminder ? 1 : 0,
        'repeatJson': jsonEncode(repeat.toJson()),
        'constantNotificationRequestId': constantNotificationRequestId,
        'completedAt': completedAt?.toIso8601String(),
        if (localId != null) 'localId': localId,
        if (serverId != null) 'serverId': serverId,
        if (lastModified != null)
          'lastModified': lastModified!.toUtc().toIso8601String(),
        'isDeleted': isDeleted ? 1 : 0,
      };

  factory Task.fromMap(Map<String, Object?> map) {
    return Task(
      id: map['id'] as String,
      title: map['title'] as String,
      description: map['description'] as String? ?? '',
      isDone: (map['isDone'] as int? ?? 0) == 1,
      theme: map['theme'] as String?,
      priority: TaskPriority.fromOptionalString(map['priority'] as String?),
      createdAt: DateTime.parse(map['createdAt'] as String),
      dueDate: map['dueDate'] != null
          ? DateTime.parse(map['dueDate'] as String)
          : null,
      endDate: map['endDate'] != null
          ? DateTime.tryParse(map['endDate'] as String)
          : null,
      allDay: (map['allDay'] as int? ?? 0) == 1,
      reminders: _parseReminders(map['remindersJson']),
      constantReminder: (map['constantReminder'] as int? ?? 0) == 1,
      repeat: _parseRepeat(map['repeatJson']),
      constantNotificationRequestId:
          map['constantNotificationRequestId'] as int?,
      completedAt: map['completedAt'] != null
          ? DateTime.parse(map['completedAt'] as String)
          : null,
      localId: map['localId'] as int?,
      serverId: map['serverId'] as int?,
      lastModified: map['lastModified'] != null
          ? DateTime.tryParse(map['lastModified'] as String)?.toUtc()
          : null,
      isDeleted: (map['isDeleted'] as int? ?? 0) == 1,
    );
  }

  static List<ScheduleReminderOffset> _parseReminders(Object? raw) {
    if (raw == null) return const [];
    try {
      final decoded = raw is String ? jsonDecode(raw) : raw;
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map(
            (e) => ScheduleReminderOffset.fromJson(
              Map<String, dynamic>.from(e),
            ),
          )
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static TaskRepeatConfig _parseRepeat(Object? raw) {
    if (raw == null) return const TaskRepeatConfig();
    try {
      final decoded = raw is String ? jsonDecode(raw) : raw;
      if (decoded is! Map) return const TaskRepeatConfig();
      return TaskRepeatConfig.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return const TaskRepeatConfig();
    }
  }
}
