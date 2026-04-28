class UserGoal {
  UserGoal({this.localId, this.id, required this.name, DateTime? lastModified})
      : lastModified = lastModified ?? DateTime.now().toUtc();

  final int? localId;
  final int? id;
  final String name;
  final DateTime lastModified;
}
