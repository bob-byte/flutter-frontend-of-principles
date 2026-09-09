import 'package:flutter/material.dart';

import 'habit_reminder.dart';

/// Notification id used by MAUI for the daily habits-report reminder.
const int kHabitsReportNotificationRequestId = 1;

class SaveHabitsReportReminderResponse {
  const SaveHabitsReportReminderResponse({
    required this.id,
    required this.userNotificationRequestId,
  });

  final int id;
  final int userNotificationRequestId;

  factory SaveHabitsReportReminderResponse.fromJson(dynamic data) {
    if (data is! Map) {
      return const SaveHabitsReportReminderResponse(
        id: 0,
        userNotificationRequestId: kHabitsReportNotificationRequestId,
      );
    }
    final map = Map<dynamic, dynamic>.from(data);
    return SaveHabitsReportReminderResponse(
      id: _asInt(map['id'] ?? map['Id']) ?? 0,
      userNotificationRequestId:
          _asInt(
            map['userNotificationRequestId'] ??
                map['UserNotificationRequestId'],
          ) ??
          kHabitsReportNotificationRequestId,
    );
  }
}

class Reminder {
  Reminder({
    this.localId,
    this.id,
    this.title = '',
    this.description = '',
    this.time = const TimeOfDay(hour: 0, minute: 0),
    this.isEnabled = false,
    this.userNotificationRequestId = kHabitsReportNotificationRequestId,
    DateTime? lastModified,
  }) : lastModified = lastModified ?? DateTime.now().toUtc();

  final int? localId;
  final int? id;
  final String title;
  final String description;
  final TimeOfDay time;
  final bool isEnabled;
  final int userNotificationRequestId;
  final DateTime lastModified;

  /// MAUI treats a reminder as unset when it has no server id and no copy.
  bool get isUnset {
    final hasId = id != null && id != 0;
    return !hasId && title.trim().isEmpty && description.trim().isEmpty;
  }

  Reminder copyWith({
    int? localId,
    int? id,
    String? title,
    String? description,
    TimeOfDay? time,
    bool? isEnabled,
    int? userNotificationRequestId,
    DateTime? lastModified,
  }) {
    return Reminder(
      localId: localId ?? this.localId,
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      time: time ?? this.time,
      isEnabled: isEnabled ?? this.isEnabled,
      userNotificationRequestId:
          userNotificationRequestId ?? this.userNotificationRequestId,
      lastModified: lastModified ?? this.lastModified,
    );
  }

  Map<String, dynamic> toJson() => {
    if (localId != null) 'localId': localId,
    'id': id ?? 0,
    'title': title,
    'description': description,
    'time': toTimeOnlyString(time),
    'isEnabled': isEnabled,
    'userNotificationRequestId': userNotificationRequestId,
    'lastModified': lastModified.toUtc().toIso8601String(),
  };

  /// Body of POST `/reminder/habitsreport/{id}` ([UserReminderDto]).
  Map<String, dynamic> toApiJson() => {
    'id': id ?? 0,
    'title': title,
    // Habit reminder Description columns are NOT NULL on the server.
    'description': description.trim(),
    'time': toTimeOnlyString(time),
    'isEnabled': isEnabled,
    'userNotificationRequestId': userNotificationRequestId == 0
        ? kHabitsReportNotificationRequestId
        : userNotificationRequestId,
  };

  factory Reminder.fromJson(dynamic data) {
    if (data is! Map) return Reminder();
    final map = Map<dynamic, dynamic>.from(data);
    final notificationId =
        _asInt(
          map['userNotificationRequestId'] ?? map['UserNotificationRequestId'],
        ) ??
        kHabitsReportNotificationRequestId;
    return Reminder(
      localId: _asInt(map['localId'] ?? map['LocalId']),
      id: _asInt(map['id'] ?? map['Id']),
      title: _asString(map['title'] ?? map['Title']) ?? '',
      description: _asString(map['description'] ?? map['Description']) ?? '',
      time: timeOfDayFromApi(map['time'] ?? map['Time']),
      isEnabled: _asBool(map['isEnabled'] ?? map['IsEnabled']),
      userNotificationRequestId: notificationId == 0
          ? kHabitsReportNotificationRequestId
          : notificationId,
      lastModified: _asDate(map['lastModified'] ?? map['LastModified']),
    );
  }
}

/// Default copy used when the server has no habits-report reminder yet.
Reminder applyHabitsReportDefaults({
  required Reminder reminder,
  required String defaultTitle,
  required String defaultDescription,
  String? userName,
}) {
  if (!reminder.isUnset) return reminder;
  final name = userName?.trim() ?? '';
  return reminder.copyWith(
    userNotificationRequestId: kHabitsReportNotificationRequestId,
    title: defaultTitle,
    description: name.isEmpty
        ? defaultDescription
        : '$name, $defaultDescription',
    isEnabled: true,
    time: const TimeOfDay(hour: 7, minute: 0),
  );
}

TimeOfDay timeOfDayFromApi(dynamic raw) {
  if (raw is TimeOfDay) return raw;
  if (raw is DateTime) {
    return TimeOfDay(hour: raw.hour, minute: raw.minute);
  }
  if (raw is String) {
    final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(raw.trim());
    if (match != null) {
      final hour = int.tryParse(match.group(1)!) ?? 0;
      final minute = int.tryParse(match.group(2)!) ?? 0;
      return TimeOfDay(hour: hour.clamp(0, 23), minute: minute.clamp(0, 59));
    }
  }
  if (raw is Map) {
    final map = Map<dynamic, dynamic>.from(raw);
    final hour =
        _asInt(map['hour'] ?? map['Hour'] ?? map['hours'] ?? map['Hours']) ?? 0;
    final minute =
        _asInt(
          map['minute'] ?? map['Minute'] ?? map['minutes'] ?? map['Minutes'],
        ) ??
        0;
    return TimeOfDay(hour: hour.clamp(0, 23), minute: minute.clamp(0, 59));
  }
  return const TimeOfDay(hour: 0, minute: 0);
}

int? _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

String? _asString(dynamic value) {
  if (value == null) return null;
  return value.toString();
}

bool _asBool(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final text = value?.toString().toLowerCase();
  return text == 'true' || text == '1';
}

DateTime? _asDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value.toUtc();
  return DateTime.tryParse(value.toString())?.toUtc();
}

/// Payload of GET `/reminder/all` (MAUI [AllRemindersResponse]).
class AllRemindersResponse {
  const AllRemindersResponse({
    this.generalReminders = const [],
    this.userHabitReminders = const [],
  });

  final List<Reminder> generalReminders;
  final List<HabitReminder> userHabitReminders;

  factory AllRemindersResponse.fromJson(dynamic data) {
    if (data is! Map) return const AllRemindersResponse();
    final map = Map<dynamic, dynamic>.from(data);
    final generalRaw = map['generalReminders'] ?? map['GeneralReminders'];
    final habitRaw = map['userHabitReminders'] ?? map['UserHabitReminders'];

    final general = <Reminder>[];
    if (generalRaw is List) {
      for (final entry in generalRaw) {
        if (entry is Map) {
          general.add(Reminder.fromJson(Map<String, dynamic>.from(entry)));
        }
      }
    }

    final habits = <HabitReminder>[];
    if (habitRaw is List) {
      for (final entry in habitRaw) {
        if (entry is Map) {
          habits.add(
            HabitReminder.fromApiJson(Map<String, dynamic>.from(entry)),
          );
        }
      }
    }

    return AllRemindersResponse(
      generalReminders: general,
      userHabitReminders: habits,
    );
  }
}
