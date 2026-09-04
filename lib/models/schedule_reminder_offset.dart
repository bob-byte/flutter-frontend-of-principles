/// Minutes before the scheduled start time (0 = on time).
class ScheduleReminderOffset {
  const ScheduleReminderOffset({
    required this.offsetMinutes,
    this.notificationRequestId,
  });

  final int offsetMinutes;
  final int? notificationRequestId;

  ScheduleReminderOffset copyWith({
    int? offsetMinutes,
    int? notificationRequestId,
  }) {
    return ScheduleReminderOffset(
      offsetMinutes: offsetMinutes ?? this.offsetMinutes,
      notificationRequestId:
          notificationRequestId ?? this.notificationRequestId,
    );
  }

  Map<String, dynamic> toJson() => {
        'offsetMinutes': offsetMinutes,
        if (notificationRequestId != null)
          'notificationRequestId': notificationRequestId,
      };

  factory ScheduleReminderOffset.fromJson(Map<String, dynamic> json) {
    return ScheduleReminderOffset(
      offsetMinutes: _asInt(json['offsetMinutes'] ?? json['OffsetMinutes']) ?? 0,
      notificationRequestId: _asInt(
        json['notificationRequestId'] ?? json['NotificationRequestId'],
      ),
    );
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }
}

/// Built-in TickTick-style presets (minutes before).
class ReminderPresets {
  static const none = -1;
  static const onTime = 0;
  static const fiveMinutes = 5;
  static const thirtyMinutes = 30;
  static const oneHour = 60;
  static const oneDay = 24 * 60;

  static const List<int> defaults = [
    onTime,
    fiveMinutes,
    thirtyMinutes,
    oneHour,
    oneDay,
  ];
}
