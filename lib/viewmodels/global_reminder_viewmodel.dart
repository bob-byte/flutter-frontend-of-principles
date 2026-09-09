import 'package:flutter/material.dart';

import '../models/reminder.dart';
import '../services/reminder_service.dart';
import '../services/user_service.dart';

enum GlobalReminderSaveResult { saved, notificationsDenied, notSupported }

class GlobalReminderViewModel extends ChangeNotifier {
  GlobalReminderViewModel({
    required ReminderService reminderService,
    required UserService userService,
  }) : _reminderService = reminderService,
       _userService = userService;

  final ReminderService _reminderService;
  final UserService _userService;

  Reminder reminder = Reminder();
  TimeOfDay time = const TimeOfDay(hour: 7, minute: 0);
  bool isEnabled = true;
  bool isLoading = true;
  bool isSaving = false;

  /// Localized defaults after applying the user-name prefix (for customize UI).
  String defaultTitle = '';
  String defaultDescription = '';

  bool matchesDefaults(String title, String description) {
    return title.trim() == defaultTitle.trim() &&
        description.trim() == defaultDescription.trim();
  }

  Future<void> load({
    required String defaultTitle,
    required String defaultDescription,
  }) async {
    isLoading = true;
    notifyListeners();
    try {
      final loaded = await _reminderService.habitsReportReminder();
      final user = await _userService.getCurrentUser();
      final appliedDefaults = applyHabitsReportDefaults(
        reminder: Reminder(),
        defaultTitle: defaultTitle,
        defaultDescription: defaultDescription,
        userName: user.name,
      );
      this.defaultTitle = appliedDefaults.title;
      this.defaultDescription = appliedDefaults.description;

      reminder = applyHabitsReportDefaults(
        reminder: loaded,
        defaultTitle: defaultTitle,
        defaultDescription: defaultDescription,
        userName: user.name,
      );
      time = reminder.time;
      isEnabled = reminder.isEnabled;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void setTime(TimeOfDay value) {
    time = value;
    notifyListeners();
  }

  void setEnabled(bool value) {
    isEnabled = value;
    notifyListeners();
  }

  Future<GlobalReminderSaveResult> save({
    required String title,
    required String description,
  }) async {
    isSaving = true;
    notifyListeners();
    try {
      if (isEnabled) {
        if (!_reminderService.isLocalNotificationSupported) {
          return GlobalReminderSaveResult.notSupported;
        }
        final allowed = await _reminderService
            .requestAccessToSendNotifications();
        if (!allowed) return GlobalReminderSaveResult.notificationsDenied;
      }

      final toSave = reminder.copyWith(
        title: title.trim(),
        description: description.trim(),
        time: time,
        isEnabled: isEnabled,
        lastModified: DateTime.now().toUtc(),
      );
      final response = await _reminderService.saveHabitsReportReminder(toSave);
      reminder = toSave.copyWith(
        id: response.id,
        userNotificationRequestId: response.userNotificationRequestId,
      );
      return GlobalReminderSaveResult.saved;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }
}
