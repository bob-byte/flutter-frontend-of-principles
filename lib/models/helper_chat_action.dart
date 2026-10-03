/// Structured “add this” item parsed from a helper assistant reply trailer.
enum HelperChatActionType { goal, habit, task, mission, slogan }

class HelperChatAction {
  const HelperChatAction({
    required this.type,
    required this.title,
    this.reason = '',
    this.goalName,
    this.notes,
  });

  final HelperChatActionType type;

  /// Display / create title (goal/habit/task name, or mission/slogan text).
  final String title;
  final String reason;

  /// Optional parent goal name when [type] is habit.
  final String? goalName;
  final String? notes;

  String get dedupeKey => '${type.name}:${title.trim().toLowerCase()}';

  factory HelperChatAction.fromJson(Map<String, dynamic> json) {
    final type = _typeFrom(json['type'] ?? json['Type']);
    final title = _firstNonEmpty([
      json['name'],
      json['Name'],
      json['title'],
      json['Title'],
      json['text'],
      json['Text'],
    ]);
    final reason = _firstNonEmpty([
      json['reason'],
      json['Reason'],
      json['reasonToFollow'],
      json['ReasonToFollow'],
    ]);
    final goalName = _nullableTrim(json['goalName'] ?? json['GoalName']);
    final notes = _nullableTrim(
      json['notes'] ??
          json['Notes'] ??
          json['description'] ??
          json['Description'],
    );
    return HelperChatAction(
      type: type,
      title: title,
      reason: reason,
      goalName: goalName,
      notes: notes,
    );
  }

  static HelperChatActionType _typeFrom(dynamic raw) {
    final value = '$raw'.trim().toLowerCase();
    return switch (value) {
      'habit' || 'habits' => HelperChatActionType.habit,
      'task' || 'tasks' => HelperChatActionType.task,
      'mission' => HelperChatActionType.mission,
      'slogan' || 'mainslogan' || 'main_slogan' => HelperChatActionType.slogan,
      _ => HelperChatActionType.goal,
    };
  }

  static String _firstNonEmpty(List<dynamic> values) {
    for (final value in values) {
      final text = '$value'.trim();
      if (text.isNotEmpty && text != 'null') return text;
    }
    return '';
  }

  static String? _nullableTrim(dynamic value) {
    if (value == null) return null;
    final text = '$value'.trim();
    if (text.isEmpty || text == 'null') return null;
    return text;
  }
}
