import '../models/reminder.dart';

class ReminderService {
  final List<Reminder> _reminders = [];

  Future<List<Reminder>> getReminders() async => List.unmodifiable(_reminders);

  Future<void> saveReminder(Reminder reminder) async {
    _reminders.add(reminder);
  }
}
