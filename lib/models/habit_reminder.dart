import 'dart:convert';
import 'package:flutter/material.dart';

class WeekDay {
  final int type; // 0 = Sunday, 1 = Monday, etc. matching DayOfWeek/DateTime.weekday % 7
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

  HabitReminder({
    this.id,
    required this.title,
    required this.description,
    required this.time,
    required this.isEnabled,
    required this.daysOfWeek,
  });

  HabitReminder copyWith({
    int? id,
    String? title,
    String? description,
    TimeOfDay? time,
    bool? isEnabled,
    List<WeekDay>? daysOfWeek,
  }) {
    return HabitReminder(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      time: time ?? this.time,
      isEnabled: isEnabled ?? this.isEnabled,
      daysOfWeek: daysOfWeek ?? List.from(this.daysOfWeek),
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
    };
  }

  factory HabitReminder.fromMap(Map<String, dynamic> map) {
    return HabitReminder(
      id: map['id'] as int?,
      title: map['title'] as String,
      description: map['description'] as String? ?? '',
      time: TimeOfDay(hour: map['time_hour'] as int? ?? 8, minute: map['time_minute'] as int? ?? 0),
      isEnabled: (map['isEnabled'] as int? ?? 1) == 1,
      daysOfWeek: (map['daysOfWeek'] as List<dynamic>?)
              ?.map((e) => WeekDay.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
