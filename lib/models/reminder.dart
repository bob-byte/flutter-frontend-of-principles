class Reminder {
  Reminder({
    this.localId,
    this.id,
    required this.title,
    this.description = '',
    required this.time,
    this.isEnabled = true,
    DateTime? lastModified,
  }) : lastModified = lastModified ?? DateTime.now().toUtc();

  final int? localId;
  final int? id;
  final String title;
  final String description;
  final String time;
  final bool isEnabled;
  final DateTime lastModified;
}
