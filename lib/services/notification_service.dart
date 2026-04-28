class NotificationService {
  Future<void> initialize() async {}

  Future<void> scheduleHabitReminder({
    required int id,
    required String title,
    required String body,
    required DateTime when,
  }) async {}

  Future<void> cancel(int id) async {}
}
