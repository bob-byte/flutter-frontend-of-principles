class ProgressOfHabit {
  ProgressOfHabit({
    this.localId,
    this.id,
    required this.userHabitLocalId,
    required this.dateAsInt,
    required this.value,
    this.notes = '',
    DateTime? lastModified,
  }) : lastModified = lastModified ?? DateTime.now().toUtc();

  final int? localId;
  final int? id;
  final int userHabitLocalId;
  final int dateAsInt;
  final int value;
  final String notes;
  final DateTime lastModified;
}
