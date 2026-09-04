import '../models/task_priority.dart';

/// Чернетка завдання, зібрана ШІ з тексту користувача.
class AiTaskDraft {
  const AiTaskDraft({
    required this.title,
    this.description = '',
    this.priority,
    this.theme,
    this.hasDueDate = false,
    this.dueDate,
  });

  final String title;
  final String description;
  final TaskPriority? priority;
  final String? theme;
  final bool hasDueDate;
  final DateTime? dueDate;

  factory AiTaskDraft.fromJson(Map<String, dynamic> json) {
    final dueRaw = json['dueDate'] ?? json['due_date'] ?? json['DueDate'];
    DateTime? dueDate;
    if (dueRaw is String && dueRaw.trim().isNotEmpty) {
      dueDate = DateTime.tryParse(dueRaw.trim());
      if (dueDate != null) {
        dueDate = DateTime(dueDate.year, dueDate.month, dueDate.day);
      }
    }

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
    );
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
}
