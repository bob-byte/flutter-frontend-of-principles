import 'dart:convert';
import 'frequency_config.dart';
import 'habit_reminder.dart';
import 'schedule_reminder_offset.dart';

enum HabitFrequency { daily, weekly, monthly, custom }

class Habit {
  final int? id;
  final String name;
  final String targetGoal; // Keeping for UI/local compat
  final int? targetGoalId; // The actual backend ID
  final bool isFlexible;
  final FrequencyConfig frequency;
  final DateTime? reminderTime;
  final int difficulty; // 1-10
  final String notes;
  final bool isArchived;
  final List<HabitReminder> reminders;
  final DateTime? lastModified;
  final int? serverId;

  /// Optional duration end as date+time (habit occurrence end).
  final DateTime? endDate;
  final bool allDay;
  final bool constantReminder;

  Habit({
    this.id,
    required this.name,
    this.targetGoal = '',
    this.targetGoalId,
    this.isFlexible = true,
    this.frequency = const FrequencyConfig(type: FrequencyType.daily),
    this.reminderTime,
    this.difficulty = 5,
    this.notes = '',
    this.isArchived = false,
    this.reminders = const [],
    this.lastModified,
    this.serverId,
    this.endDate,
    this.allDay = false,
    this.constantReminder = false,
  });

  Habit copyWith({
    int? id,
    String? name,
    String? targetGoal,
    int? targetGoalId,
    bool? isFlexible,
    FrequencyConfig? frequency,
    DateTime? reminderTime,
    int? difficulty,
    String? notes,
    bool? isArchived,
    List<HabitReminder>? reminders,
    DateTime? lastModified,
    int? serverId,
    DateTime? endDate,
    bool clearEndDate = false,
    bool? allDay,
    bool? constantReminder,
  }) {
    return Habit(
      id: id ?? this.id,
      name: name ?? this.name,
      targetGoal: targetGoal ?? this.targetGoal,
      targetGoalId: targetGoalId ?? this.targetGoalId,
      isFlexible: isFlexible ?? this.isFlexible,
      frequency: frequency ?? this.frequency,
      reminderTime: reminderTime ?? this.reminderTime,
      difficulty: difficulty ?? this.difficulty,
      notes: notes ?? this.notes,
      isArchived: isArchived ?? this.isArchived,
      reminders: reminders ?? this.reminders,
      lastModified: lastModified ?? this.lastModified,
      serverId: serverId ?? this.serverId,
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
      allDay: allDay ?? this.allDay,
      constantReminder: constantReminder ?? this.constantReminder,
    );
  }

  List<ScheduleReminderOffset> get reminderOffsets {
    if (reminders.isEmpty) return const [];
    return reminders.first.offsets;
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'targetGoal': targetGoal,
      'targetGoalId': targetGoalId,
      'isFlexible': isFlexible ? 1 : 0,
      'frequency': jsonEncode(frequency.toMap()),
      'reminderTime': reminderTime?.toIso8601String(),
      'difficulty': difficulty,
      'notes': notes,
      'isArchived': isArchived ? 1 : 0,
      'reminders': jsonEncode(reminders.map((r) => r.toMap()).toList()),
      'lastModified': lastModified?.toUtc().toIso8601String(),
      'serverId': serverId,
      'endDate': endDate?.toIso8601String(),
      'allDay': allDay ? 1 : 0,
      'constantReminder': constantReminder ? 1 : 0,
    };
  }

  factory Habit.fromMap(Map<String, dynamic> map) {
    FrequencyConfig parsedFrequency = const FrequencyConfig(
      type: FrequencyType.daily,
    );
    if (map['frequency'] != null) {
      final String freqStr = map['frequency'] as String;
      if (freqStr.startsWith('{')) {
        try {
          parsedFrequency = FrequencyConfig.fromMap(jsonDecode(freqStr));
        } catch (e) {
          // Fallback to default
        }
      }
    }

    List<HabitReminder> parsedReminders = [];
    if (map['reminders'] != null) {
      try {
        final List<dynamic> decoded = jsonDecode(map['reminders'] as String);
        parsedReminders = decoded
            .map((e) => HabitReminder.fromMap(e as Map<String, dynamic>))
            .toList();
      } catch (_) {}
    }

    return Habit(
      id: map['id'] as int?,
      name: map['name'] as String,
      targetGoal: map['targetGoal'] as String? ?? '',
      targetGoalId: map['targetGoalId'] as int?,
      isFlexible: (map['isFlexible'] as int? ?? 1) == 1,
      frequency: parsedFrequency,
      reminderTime: map['reminderTime'] != null
          ? DateTime.parse(map['reminderTime'] as String)
          : null,
      difficulty: map['difficulty'] as int? ?? 5,
      notes: map['notes'] as String? ?? '',
      isArchived: _readBool(map['isArchived']),
      reminders: parsedReminders,
      lastModified: map['lastModified'] != null
          ? DateTime.tryParse(map['lastModified'] as String)?.toUtc()
          : null,
      serverId: map['serverId'] as int?,
      endDate: map['endDate'] != null
          ? DateTime.tryParse(map['endDate'] as String)
          : null,
      allDay: _readBool(map['allDay']),
      constantReminder: _readBool(map['constantReminder']),
    );
  }
}

bool _readBool(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    return value == '1' || value.toLowerCase() == 'true';
  }
  return false;
}
