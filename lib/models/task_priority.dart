import '../l10n/task_strings.dart';

enum TaskPriority {
  low,
  medium,
  high;

  String label(TaskStrings strings) => switch (this) {
        TaskPriority.low => strings.taskPriorityLow,
        TaskPriority.medium => strings.taskPriorityMedium,
        TaskPriority.high => strings.taskPriorityHigh,
      };

  static TaskPriority fromString(String value) => switch (value) {
        'low' => TaskPriority.low,
        'high' => TaskPriority.high,
        _ => TaskPriority.medium,
      };

  static TaskPriority? fromOptionalString(String? value) => switch (value) {
        'low' => TaskPriority.low,
        'medium' => TaskPriority.medium,
        'high' => TaskPriority.high,
        'none' || '' => null,
        null => null,
        _ => TaskPriority.medium,
      };

  String toStorage() => name;
}
