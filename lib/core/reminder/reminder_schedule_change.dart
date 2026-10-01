import 'dart:convert';

import '../../models/habit.dart';
import '../../models/task.dart';

/// Whether a task merged from the server needs its local notifications
/// rebuilt. [before] is the local row prior to the merge (null = new here).
bool taskReminderScheduleChanged(Task? before, Task after) {
  if (before == null) {
    return !after.isDone &&
        after.dueDate != null &&
        (after.reminders.isNotEmpty || after.constantReminder);
  }
  return before.isDone != after.isDone ||
      !_sameMoment(before.dueDate, after.dueDate) ||
      before.title != after.title ||
      before.description != after.description ||
      before.constantReminder != after.constantReminder ||
      before.constantNotificationRequestId !=
          after.constantNotificationRequestId ||
      jsonEncode([for (final r in before.reminders) r.toJson()]) !=
          jsonEncode([for (final r in after.reminders) r.toJson()]);
}

/// Whether a habit merged from the server needs its local notifications
/// rebuilt. [before] is the local row prior to the merge (null = new here).
bool habitReminderScheduleChanged(Habit? before, Habit after) {
  if (before == null) {
    return !after.isArchived && after.reminders.any((r) => r.isEnabled);
  }
  final wantsConstant = _wantsConstant(after);
  return before.isArchived != after.isArchived ||
      _wantsConstant(before) != wantsConstant ||
      (wantsConstant && before.name != after.name) ||
      jsonEncode([for (final r in before.reminders) r.toMap()]) !=
          jsonEncode([for (final r in after.reminders) r.toMap()]);
}

/// Bootstrap habits carry the constant flag only on their reminders.
bool _wantsConstant(Habit habit) =>
    habit.constantReminder || habit.reminders.any((r) => r.constantReminder);

bool _sameMoment(DateTime? a, DateTime? b) {
  if (a == null || b == null) return a == b;
  return a.isAtSameMomentAs(b);
}
