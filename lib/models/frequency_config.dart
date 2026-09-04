enum FrequencyType { daily, everyXDays, timesPerPeriod }

enum PeriodType { week, month }

class FrequencyConfig {
  final FrequencyType type;
  final int? interval;
  final PeriodType? period;

  const FrequencyConfig({required this.type, this.interval, this.period});

  Map<String, dynamic> toMap() {
    return {'type': type.name, 'interval': interval, 'period': period?.name};
  }

  factory FrequencyConfig.fromMap(Map<String, dynamic> map) {
    return FrequencyConfig(
      type: FrequencyType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => FrequencyType.daily,
      ),
      interval: map['interval'] as int?,
      period: map['period'] != null
          ? PeriodType.values.firstWhere(
              (e) => e.name == map['period'],
              orElse: () => PeriodType.week,
            )
          : null,
    );
  }

  /// .NET [FrequencyOfHabit.Repeats].
  int get repeats {
    switch (type) {
      case FrequencyType.daily:
      case FrequencyType.everyXDays:
        return 1;
      case FrequencyType.timesPerPeriod:
        return (interval ?? 1).clamp(1, 365);
    }
  }

  /// .NET [FrequencyOfHabit.IntervalLengthInDays].
  int get intervalLengthInDays {
    switch (type) {
      case FrequencyType.daily:
        return 1;
      case FrequencyType.everyXDays:
        return (interval ?? 1).clamp(1, 365);
      case FrequencyType.timesPerPeriod:
        return period == PeriodType.month ? 30 : 7;
    }
  }

  /// .NET [FrequencyOfHabit.Value] — repeats / interval length.
  double get frequencyValue => repeats / intervalLengthInDays;

  String get displayString {
    switch (type) {
      case FrequencyType.daily:
        return 'Кожного дня';
      case FrequencyType.everyXDays:
        return 'Кожні ${interval ?? 1} дні(-ів)';
      case FrequencyType.timesPerPeriod:
        final periodStr = period == PeriodType.month ? 'місяць' : 'тиждень';
        return '${interval ?? 1} рази(-ів) на $periodStr';
    }
  }

  // To support old string-based habits gracefully
  factory FrequencyConfig.fromString(String freq) {
    if (freq.startsWith('Кожні')) {
      final parts = freq.split(' ');
      int? interval = 3;
      if (parts.length >= 2) {
        interval = int.tryParse(parts[1]) ?? 3;
      }
      return FrequencyConfig(
        type: FrequencyType.everyXDays,
        interval: interval,
      );
    } else if (freq.contains('на ')) {
      final parts = freq.split(' ');
      int? interval = 3;
      if (parts.isNotEmpty) {
        interval = int.tryParse(parts[0]) ?? 3;
      }
      PeriodType period = PeriodType.week;
      if (parts.last.contains('місяць')) {
        period = PeriodType.month;
      }
      return FrequencyConfig(
        type: FrequencyType.timesPerPeriod,
        interval: interval,
        period: period,
      );
    }
    return const FrequencyConfig(type: FrequencyType.daily);
  }
}
