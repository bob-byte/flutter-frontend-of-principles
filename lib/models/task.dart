import 'task_priority.dart';

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
    this.completedAt,
  });

  final String id;
  final String title;
  final String description;
  final bool isDone;
  final String? theme;
  final TaskPriority? priority;
  final DateTime createdAt;
  final DateTime? dueDate;
  final DateTime? completedAt;

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
    DateTime? completedAt,
    bool clearCompletedAt = false,
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
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
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
        'completedAt': completedAt?.toIso8601String(),
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
      completedAt: map['completedAt'] != null
          ? DateTime.parse(map['completedAt'] as String)
          : null,
    );
  }
}
