import 'dart:convert';
import 'frequency_config.dart';
import 'habit_reminder.dart';
import 'area_of_life.dart';

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
  final List<AreaOfLife> areasOfLife;

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
    this.areasOfLife = const [],
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
    List<AreaOfLife>? areasOfLife,
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
      areasOfLife: areasOfLife ?? this.areasOfLife,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
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
      'areasOfLife': jsonEncode(areasOfLife.map((a) => a.toMap()).toList()),
    };
  }

  factory Habit.fromMap(Map<String, dynamic> map) {
    FrequencyConfig parsedFrequency = const FrequencyConfig(type: FrequencyType.daily);
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
        parsedReminders = decoded.map((e) => HabitReminder.fromMap(e as Map<String, dynamic>)).toList();
      } catch (_) {}
    }

    List<AreaOfLife> parsedAreas = [];
    if (map['areasOfLife'] != null) {
      try {
        final List<dynamic> decoded = jsonDecode(map['areasOfLife'] as String);
        parsedAreas = decoded.map((e) => AreaOfLife.fromMap(e as Map<String, dynamic>)).toList();
      } catch (_) {}
    }

    return Habit(
      id: map['id'] as int?,
      name: map['name'] as String,
      targetGoal: map['targetGoal'] as String? ?? '',
      targetGoalId: map['targetGoalId'] as int?,
      isFlexible: (map['isFlexible'] as int? ?? 1) == 1,
      frequency: parsedFrequency,
      reminderTime: map['reminderTime'] != null ? DateTime.parse(map['reminderTime'] as String) : null,
      difficulty: map['difficulty'] as int? ?? 5,
      notes: map['notes'] as String? ?? '',
      isArchived: (map['isArchived'] as int? ?? 0) == 1,
      reminders: parsedReminders,
      areasOfLife: parsedAreas,
    );
  }
}
