import 'package:flutter/material.dart';

import 'schedule_reminder_offset.dart';

/// Converts a stored weekday to .NET [DayOfWeek] (Sunday = 0 … Saturday = 6).
///
/// The reminder UI uses [DateTime.weekday] (Monday = 1 … Sunday = 7). Sunday is
/// the only value that differs from [DayOfWeek].
int toDotNetDayOfWeek(int storedType) => storedType % 7;

String toTimeOnlyString(TimeOfDay time) {
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute:00';
}

class WeekDay {
  final int type; // DateTime.weekday (1=Mon…7=Sun) or DayOfWeek (0=Sun…6=Sat)
  final int userNotificationRequestId;

  WeekDay({
    required this.type,
    required this.userNotificationRequestId,
  });

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'userNotificationRequestId': userNotificationRequestId,
    };
  }

  factory WeekDay.fromMap(Map<String, dynamic> map) {
    return WeekDay(
      type: map['type'] as int,
      userNotificationRequestId: map['userNotificationRequestId'] as int,
    );
  }
}

class HabitReminder {
  int? id;
  String title;
  String description;
  TimeOfDay time;
  bool isEnabled;
  List<WeekDay> daysOfWeek;
  List<ScheduleReminderOffset> offsets;
  bool constantReminder;
  int? constantNotificationRequestId;
  TimeOfDay? endTime;
  bool allDay;

  HabitReminder({
    this.id,
    required this.title,
    required this.description,
    required this.time,
    required this.isEnabled,
    required this.daysOfWeek,
    this.offsets = const [],
    this.constantReminder = false,
    this.constantNotificationRequestId,
    this.endTime,
    this.allDay = false,
  });

  HabitReminder copyWith({
    int? id,
    String? title,
    String? description,
    TimeOfDay? time,
    bool? isEnabled,
    List<WeekDay>? daysOfWeek,
    List<ScheduleReminderOffset>? offsets,
    bool? constantReminder,
    int? constantNotificationRequestId,
    TimeOfDay? endTime,
    bool clearEndTime = false,
    bool? allDay,
  }) {
    return HabitReminder(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      time: time ?? this.time,
      isEnabled: isEnabled ?? this.isEnabled,
      daysOfWeek: daysOfWeek ?? List.from(this.daysOfWeek),
      offsets: offsets ?? List.from(this.offsets),
      constantReminder: constantReminder ?? this.constantReminder,
      constantNotificationRequestId:
          constantNotificationRequestId ?? this.constantNotificationRequestId,
      endTime: clearEndTime ? null : (endTime ?? this.endTime),
      allDay: allDay ?? this.allDay,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'time_hour': time.hour,
      'time_minute': time.minute,
      'isEnabled': isEnabled ? 1 : 0,
      'daysOfWeek': daysOfWeek.map((e) => e.toMap()).toList(),
      'offsets': offsets.map((e) => e.toJson()).toList(),
      'constantReminder': constantReminder ? 1 : 0,
      'constantNotificationRequestId': constantNotificationRequestId,
      if (endTime != null) 'end_time_hour': endTime!.hour,
      if (endTime != null) 'end_time_minute': endTime!.minute,
      'allDay': allDay ? 1 : 0,
    };
  }

  factory HabitReminder.fromMap(Map<String, dynamic> map) {
    final offsetsRaw = map['offsets'];
    final offsets = <ScheduleReminderOffset>[];
    if (offsetsRaw is List) {
      for (final e in offsetsRaw) {
        if (e is Map) {
          offsets.add(
            ScheduleReminderOffset.fromJson(Map<String, dynamic>.from(e)),
          );
        }
      }
    }

    TimeOfDay? endTime;
    if (map['end_time_hour'] != null) {
      endTime = TimeOfDay(
        hour: map['end_time_hour'] as int? ?? 0,
        minute: map['end_time_minute'] as int? ?? 0,
      );
    }

    return HabitReminder(
      id: map['id'] as int?,
      title: map['title'] as String,
      description: map['description'] as String? ?? '',
      time: TimeOfDay(
        hour: map['time_hour'] as int? ?? 8,
        minute: map['time_minute'] as int? ?? 0,
      ),
      isEnabled: (map['isEnabled'] as int? ?? 1) == 1,
      daysOfWeek: (map['daysOfWeek'] as List<dynamic>?)
              ?.map((e) => WeekDay.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
      offsets: offsets,
      constantReminder: (map['constantReminder'] as int? ?? 0) == 1,
      constantNotificationRequestId:
          map['constantNotificationRequestId'] as int?,
      endTime: endTime,
      allDay: (map['allDay'] as int? ?? 0) == 1,
    );
  }
}
