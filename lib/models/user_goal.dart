class UserGoal {
  UserGoal({
    this.localId,
    this.id,
    required this.name,
    this.isCompleted = false,
    DateTime? lastModified,
  }) : lastModified = lastModified ?? DateTime.now().toUtc();

  final int? localId;
  final int? id;
  final String name;
  final bool isCompleted;
  final DateTime lastModified;

  UserGoal copyWith({
    int? localId,
    int? id,
    String? name,
    bool? isCompleted,
    DateTime? lastModified,
  }) {
    return UserGoal(
      localId: localId ?? this.localId,
      id: id ?? this.id,
      name: name ?? this.name,
      isCompleted: isCompleted ?? this.isCompleted,
      lastModified: lastModified ?? this.lastModified,
    );
  }

  Map<String, dynamic> toJson() => {
    if (localId != null) 'localId': localId,
    'id': id,
    'name': name,
    'isCompleted': isCompleted,
    'lastModified': lastModified.toUtc().toIso8601String(),
  };

  factory UserGoal.fromJson(Map map) {
    return UserGoal(
      localId: _asInt(map['localId']),
      id: _asInt(map['id'] ?? map['Id']),
      name: '${map['name'] ?? map['Name'] ?? ''}',
      isCompleted: _asBool(map['isCompleted'] ?? map['IsCompleted']),
      lastModified: _asDate(map['lastModified'] ?? map['LastModified']),
    );
  }

  static int compareForDisplay(UserGoal a, UserGoal b) {
    if (a.isCompleted != b.isCompleted) {
      return a.isCompleted ? 1 : -1;
    }
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  }
}

int? _asInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('$value');
}

bool _asBool(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    return value == '1' || value.toLowerCase() == 'true';
  }
  return false;
}

DateTime? _asDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value.toUtc();
  return DateTime.tryParse(value.toString())?.toUtc();
}
