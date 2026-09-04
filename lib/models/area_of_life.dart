class AreaOfLife {
  final int id;
  final String name;

  const AreaOfLife({
    required this.id,
    required this.name,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
    };
  }

  factory AreaOfLife.fromMap(Map<String, dynamic> map) {
    return AreaOfLife(
      id: map['id'] as int,
      name: map['name'] as String,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AreaOfLife && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

final allAreasFakeItem = const AreaOfLife(id: 0, name: "All areas of life");
