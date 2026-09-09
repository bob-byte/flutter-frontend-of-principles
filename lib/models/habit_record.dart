import 'progress_value.dart';

enum HabitStatus { none, completed, skipped }

class HabitRecord {
  HabitRecord({
    this.id,
    required this.habitId,
    required this.date,
    HabitStatus? status,
    int? value,
    this.lastModified,
  }) : value = value ?? progressValueFromStatus(status ?? HabitStatus.none);

  final int? id;
  final int habitId;
  final DateTime date;
  final DateTime? lastModified;

  /// Raw .NET [ProgressValue].
  final int value;

  HabitStatus get status => habitStatusFromProgressValue(value);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'habitId': habitId,
      'date': date.toIso8601String().substring(0, 10),
      'status': status.index,
      'value': value,
      if (lastModified != null)
        'lastModified': lastModified!.toUtc().toIso8601String(),
    };
  }

  factory HabitRecord.fromMap(Map<String, dynamic> map) {
    return HabitRecord(
      id: map['id'] as int?,
      habitId: map['habitId'] as int,
      date: DateTime.parse(map['date'] as String),
      value: progressValueFromMap(map),
      lastModified: map['lastModified'] != null
          ? DateTime.tryParse('${map['lastModified']}')?.toUtc()
          : null,
    );
  }
}

int progressValueFromStatus(HabitStatus status) {
  switch (status) {
    case HabitStatus.completed:
      return kProgressYesManual;
    case HabitStatus.skipped:
      return kProgressSkip;
    case HabitStatus.none:
      return kProgressUnknown;
  }
}

HabitStatus habitStatusFromProgressValue(int value) {
  if (value == kProgressYesManual || value == kProgressYesAuto) {
    return HabitStatus.completed;
  }
  if (value == kProgressSkip) {
    return HabitStatus.skipped;
  }
  return HabitStatus.none;
}

int progressValueFromMap(Map<String, dynamic> map) {
  final raw = map['value'];
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  if (raw is String) {
    final parsed = int.tryParse(raw);
    if (parsed != null) return parsed;
  }

  final statusIndex = map['status'] as int? ?? 0;
  if (statusIndex >= 0 && statusIndex < HabitStatus.values.length) {
    return progressValueFromStatus(HabitStatus.values[statusIndex]);
  }
  return kProgressUnknown;
}
