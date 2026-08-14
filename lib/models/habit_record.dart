enum HabitStatus { none, completed, skipped }

class HabitRecord {
  final int? id;
  final int habitId;
  final DateTime date;
  final HabitStatus status;

  HabitRecord({
    this.id,
    required this.habitId,
    required this.date,
    required this.status,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'habitId': habitId,
      // Зберігаємо як YYYY-MM-DD для швидких запитів
      'date': date.toIso8601String().substring(0, 10), 
      'status': status.index,
    };
  }

  factory HabitRecord.fromMap(Map<String, dynamic> map) {
    return HabitRecord(
      id: map['id'] as int?,
      habitId: map['habitId'] as int,
      date: DateTime.parse(map['date'] as String),
      status: HabitStatus.values[map['status'] as int? ?? 0],
    );
  }
}
