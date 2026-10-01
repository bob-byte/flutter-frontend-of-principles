/// Data-only silent push sent by the backend when another device changes or
/// deletes tasks/habits (`POST` FCM `data` map, string values only).
class SyncPushMessage {
  const SyncPushMessage({
    this.deletedTaskIds = const [],
    this.deletedHabitIds = const [],
  });

  static const type = 'sync';

  /// Server ids another device deleted — cancelled before the sync finishes.
  final List<int> deletedTaskIds;
  final List<int> deletedHabitIds;

  static SyncPushMessage? tryParse(Map<String, dynamic> data) {
    if (data['type'] != type) return null;
    return SyncPushMessage(
      deletedTaskIds: _ids(data['deletedTaskIds']),
      deletedHabitIds: _ids(data['deletedHabitIds']),
    );
  }

  Map<String, String> toData() => {
    'type': type,
    'deletedTaskIds': deletedTaskIds.join(','),
    'deletedHabitIds': deletedHabitIds.join(','),
  };

  static List<int> _ids(Object? raw) {
    if (raw == null) return const [];
    return '$raw'
        .split(',')
        .map((part) => int.tryParse(part.trim()))
        .whereType<int>()
        .where((id) => id > 0)
        .toList();
  }
}
