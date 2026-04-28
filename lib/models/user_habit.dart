class UserHabit {
  UserHabit({
    this.localId,
    this.id,
    required this.name,
    this.description = '',
    this.goalName,
    this.frequencyText = '',
    this.reminderText = '',
    this.isArchived = false,
    DateTime? lastModified,
  }) : lastModified = lastModified ?? DateTime.now().toUtc();

  final int? localId;
  final int? id;
  final String name;
  final String description;
  final String? goalName;
  final String frequencyText;
  final String reminderText;
  final bool isArchived;
  final DateTime lastModified;
}
