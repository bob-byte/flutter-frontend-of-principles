import '../models/schedule_reminder_offset.dart';
import '../models/task_priority.dart';
import '../models/task_subtask.dart';

/// Чернетка завдання, зібрана ШІ з тексту користувача.
class AiTaskDraft {
  const AiTaskDraft({
    required this.title,
    this.description = '',
    this.priority,
    this.theme,
    this.hasDueDate = false,
    this.dueDate,
    this.allDay = false,
    this.reminders = const [],
    this.subtasks = const [],
  });

  final String title;
  final String description;
  final TaskPriority? priority;
  final String? theme;
  final bool hasDueDate;

  /// Local due date; may include a clock time when [allDay] is false.
  final DateTime? dueDate;
  final bool allDay;
  final List<ScheduleReminderOffset> reminders;
  final List<TaskSubtask> subtasks;

  factory AiTaskDraft.fromJson(Map<String, dynamic> json) {
    final dueRaw = json['dueDate'] ?? json['due_date'] ?? json['DueDate'];
    DateTime? dueDate;
    var hasClockTime = false;
    if (dueRaw is String && dueRaw.trim().isNotEmpty) {
      final parsed = _parseLocalDue(dueRaw.trim());
      dueDate = parsed.due;
      hasClockTime = parsed.hasTime;
    }

    final allDayRaw = json['allDay'] ?? json['AllDay'];
    final allDay = allDayRaw is bool
        ? allDayRaw
        : (dueDate == null ? false : !hasClockTime);

    return AiTaskDraft(
      title: (json['title'] ?? json['Title'] ?? '').toString().trim(),
      description: (json['description'] ?? json['Description'] ?? '')
          .toString()
          .trim(),
      priority: _priorityFrom(json['priority'] ?? json['Priority']),
      theme: _nullableString(
        json['theme'] ?? json['Theme'] ?? json['category'],
      ),
      hasDueDate: dueDate != null,
      dueDate: dueDate,
      allDay: dueDate != null && allDay,
      reminders: _remindersFrom(json['reminders'] ?? json['Reminders']),
      subtasks: _subtasksFrom(json['subtasks'] ?? json['Subtasks']),
    );
  }

  static ({DateTime? due, bool hasTime}) _parseLocalDue(String raw) {
    // Treat wall-clock values without a timezone as local (never shift to UTC).
    final normalized = raw.trim();
    final hasTime =
        normalized.contains('T') ||
        RegExp(r'\d{1,2}:\d{2}').hasMatch(normalized);

    // Strip trailing Z / offset so DateTime.tryParse won't force UTC.
    final withoutZone = normalized
        .replaceFirst(RegExp(r'(Z|[+-]\d{2}:?\d{2})$'), '')
        .trim();

    final parsed = DateTime.tryParse(withoutZone);
    if (parsed == null) {
      return (due: null, hasTime: false);
    }

    if (!hasTime) {
      return (
        due: DateTime(parsed.year, parsed.month, parsed.day),
        hasTime: false,
      );
    }

    return (
      due: DateTime(
        parsed.year,
        parsed.month,
        parsed.day,
        parsed.hour,
        parsed.minute,
      ),
      hasTime: true,
    );
  }

  static List<ScheduleReminderOffset> _remindersFrom(Object? raw) {
    if (raw == null) return const [];
    if (raw is! List) {
      final single = _asInt(raw);
      if (single == null || single < 0) return const [];
      return [ScheduleReminderOffset(offsetMinutes: single)];
    }

    final seen = <int>{};
    final result = <ScheduleReminderOffset>[];
    for (final entry in raw) {
      int? minutes;
      if (entry is num) {
        minutes = entry.toInt();
      } else if (entry is Map) {
        minutes = _asInt(
          entry['offsetMinutes'] ?? entry['OffsetMinutes'] ?? entry['minutes'],
        );
      } else {
        minutes = _asInt(entry);
      }
      if (minutes == null || minutes < 0 || minutes > 60 * 24 * 30) continue;
      if (!seen.add(minutes)) continue;
      result.add(ScheduleReminderOffset(offsetMinutes: minutes));
    }
    result.sort((a, b) => a.offsetMinutes.compareTo(b.offsetMinutes));
    return result;
  }

  static List<TaskSubtask> _subtasksFrom(Object? raw) {
    if (raw == null) return const [];
    if (raw is! List) return const [];

    final result = <TaskSubtask>[];
    for (final entry in raw) {
      String title;
      if (entry is String) {
        title = entry.trim();
      } else if (entry is Map) {
        title =
            (entry['title'] ??
                    entry['Title'] ??
                    entry['name'] ??
                    entry['Name'] ??
                    '')
                .toString()
                .trim();
      } else {
        title = entry.toString().trim();
      }
      if (title.isEmpty) continue;
      result.add(
        TaskSubtask(
          id: TaskSubtask.allocateId(),
          title: title,
          sortOrder: result.length,
        ),
      );
      if (result.length >= 30) break;
    }
    return result;
  }

  static TaskPriority? _priorityFrom(Object? value) {
    if (value == null) return null;
    final raw = value.toString().trim().toLowerCase();
    if (raw.isEmpty || raw == 'null' || raw == 'none') return null;
    if (raw.contains('high') ||
        raw.contains('висок') ||
        raw.contains('urgent') ||
        raw.contains('термін')) {
      return TaskPriority.high;
    }
    if (raw.contains('medium') ||
        raw.contains('середн') ||
        raw.contains('normal')) {
      return TaskPriority.medium;
    }
    if (raw.contains('low') || raw.contains('низ')) {
      return TaskPriority.low;
    }
    return null;
  }

  static String? _nullableString(Object? value) {
    if (value == null) return null;
    final text = value.toString().trim();
    if (text.isEmpty || text.toLowerCase() == 'null') return null;
    return text;
  }

  static int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }
}
