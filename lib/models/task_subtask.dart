import 'dart:convert';

class TaskSubtask {
  const TaskSubtask({
    required this.id,
    required this.title,
    this.isDone = false,
    this.sortOrder = 0,
  });

  final String id;
  final String title;
  final bool isDone;
  final int sortOrder;

  static var _nextSerial = 0;

  static String allocateId() {
    _nextSerial += 1;
    return 'S${DateTime.now().microsecondsSinceEpoch}_$_nextSerial';
  }

  TaskSubtask copyWith({
    String? id,
    String? title,
    bool? isDone,
    int? sortOrder,
  }) {
    return TaskSubtask(
      id: id ?? this.id,
      title: title ?? this.title,
      isDone: isDone ?? this.isDone,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': title,
    'isCompleted': isDone,
    'sortOrder': sortOrder,
  };

  factory TaskSubtask.fromJson(Map<String, dynamic> json) {
    final id = '${json['id'] ?? json['Id'] ?? ''}'.trim();
    final title =
        '${json['name'] ?? json['Name'] ?? json['title'] ?? json['Title'] ?? ''}'
            .trim();
    return TaskSubtask(
      id: id.isEmpty ? allocateId() : id,
      title: title,
      isDone:
          json['isCompleted'] == true ||
          json['IsCompleted'] == true ||
          json['isDone'] == true,
      sortOrder: _asInt(json['sortOrder'] ?? json['SortOrder']) ?? 0,
    );
  }

  static List<TaskSubtask> listFromJson(Object? raw) {
    if (raw == null) return const [];
    try {
      final decoded = raw is String ? jsonDecode(raw) : raw;
      if (decoded is! List) return const [];
      final items = <TaskSubtask>[];
      for (final entry in decoded) {
        if (entry is! Map) continue;
        items.add(TaskSubtask.fromJson(Map<String, dynamic>.from(entry)));
      }
      items.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      return items;
    } catch (_) {
      return const [];
    }
  }

  static List<TaskSubtask> sanitize(Iterable<TaskSubtask> items) {
    final result = <TaskSubtask>[];
    for (final item in items) {
      final title = item.title.trim();
      if (title.isEmpty) continue;
      result.add(item.copyWith(title: title, sortOrder: result.length));
    }
    return result;
  }

  /// Copies the checklist onto a repeating occurrence with fresh ids, all open.
  static List<TaskSubtask> templateForNextOccurrence(
    Iterable<TaskSubtask> items,
  ) {
    return [
      for (final item in sanitize(items))
        item.copyWith(id: allocateId(), isDone: false),
    ];
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  @override
  bool operator ==(Object other) {
    return other is TaskSubtask &&
        other.id == id &&
        other.title == title &&
        other.isDone == isDone &&
        other.sortOrder == sortOrder;
  }

  @override
  int get hashCode => Object.hash(id, title, isDone, sortOrder);
}
