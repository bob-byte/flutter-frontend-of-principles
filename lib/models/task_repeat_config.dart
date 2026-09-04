enum TaskRepeatPreset {
  none,
  daily,
  weekly,
  monthly,
  yearly,
  weekday,
  custom,
}

enum TaskRepeatUnit { day, week, month, year }

/// When advancing a repeating task after completion.
enum TaskRepeatAnchor { dueDates, completion }

class TaskRepeatConfig {
  const TaskRepeatConfig({
    this.preset = TaskRepeatPreset.none,
    this.interval = 1,
    this.unit = TaskRepeatUnit.day,
    this.weekdays = const [],
    this.anchor = TaskRepeatAnchor.dueDates,
  });

  final TaskRepeatPreset preset;
  final int interval;
  final TaskRepeatUnit unit;

  /// DateTime.weekday values (1=Mon … 7=Sun). Used for weekly / weekday / custom week.
  final List<int> weekdays;
  final TaskRepeatAnchor anchor;

  bool get isNone => preset == TaskRepeatPreset.none;

  TaskRepeatConfig copyWith({
    TaskRepeatPreset? preset,
    int? interval,
    TaskRepeatUnit? unit,
    List<int>? weekdays,
    TaskRepeatAnchor? anchor,
  }) {
    return TaskRepeatConfig(
      preset: preset ?? this.preset,
      interval: interval ?? this.interval,
      unit: unit ?? this.unit,
      weekdays: weekdays ?? List<int>.from(this.weekdays),
      anchor: anchor ?? this.anchor,
    );
  }

  Map<String, dynamic> toJson() => {
        'preset': preset.name,
        'interval': interval,
        'unit': unit.name,
        'weekdays': weekdays,
        'anchor': anchor.name,
      };

  factory TaskRepeatConfig.fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) {
      return const TaskRepeatConfig();
    }
    final presetName = (json['preset'] ?? json['Preset'])?.toString();
    final unitName = (json['unit'] ?? json['Unit'])?.toString();
    final anchorName = (json['anchor'] ?? json['Anchor'])?.toString();
    final rawDays = json['weekdays'] ?? json['Weekdays'];
    final days = <int>[];
    if (rawDays is List) {
      for (final d in rawDays) {
        final v = d is int ? d : int.tryParse(d.toString());
        if (v != null) days.add(v);
      }
    }
    return TaskRepeatConfig(
      preset: TaskRepeatPreset.values.firstWhere(
        (e) => e.name == presetName,
        orElse: () => TaskRepeatPreset.none,
      ),
      interval: _asInt(json['interval'] ?? json['Interval']) ?? 1,
      unit: TaskRepeatUnit.values.firstWhere(
        (e) => e.name == unitName,
        orElse: () => TaskRepeatUnit.day,
      ),
      weekdays: days,
      anchor: TaskRepeatAnchor.values.firstWhere(
        (e) => e.name == anchorName,
        orElse: () => TaskRepeatAnchor.dueDates,
      ),
    );
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  /// Factory helpers for presets anchored to [selectedDay].
  factory TaskRepeatConfig.daily() =>
      const TaskRepeatConfig(preset: TaskRepeatPreset.daily);

  factory TaskRepeatConfig.weekly(DateTime day) => TaskRepeatConfig(
        preset: TaskRepeatPreset.weekly,
        unit: TaskRepeatUnit.week,
        weekdays: [day.weekday],
      );

  factory TaskRepeatConfig.monthly() => const TaskRepeatConfig(
        preset: TaskRepeatPreset.monthly,
        unit: TaskRepeatUnit.month,
      );

  factory TaskRepeatConfig.yearly() => const TaskRepeatConfig(
        preset: TaskRepeatPreset.yearly,
        unit: TaskRepeatUnit.year,
      );

  factory TaskRepeatConfig.everyWeekday() => const TaskRepeatConfig(
        preset: TaskRepeatPreset.weekday,
        unit: TaskRepeatUnit.week,
        weekdays: [
          DateTime.monday,
          DateTime.tuesday,
          DateTime.wednesday,
          DateTime.thursday,
          DateTime.friday,
        ],
      );
}
