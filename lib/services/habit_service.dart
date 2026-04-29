import '../models/user_habit.dart';

class HabitService {
  final List<UserHabit> _habits = [];
  int _nextLocalId = 1;

  Future<List<UserHabit>> getHabits() async => List.unmodifiable(_habits);
  Future<UserHabit?> getHabitByLocalId(int localId) async {
    try {
      return _habits.firstWhere((h) => h.localId == localId);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveHabit(UserHabit habit, {required String defaultFrequencyText}) async {
    final localId = habit.localId ?? _nextLocalId++;
    final normalized = UserHabit(
      localId: localId,
      id: habit.id,
      name: habit.name,
      description: habit.description,
      goalName: habit.goalName,
      frequencyText: habit.frequencyText.isEmpty ? defaultFrequencyText : habit.frequencyText,
      reminderText: habit.reminderText,
      isArchived: habit.isArchived,
      lastModified: habit.lastModified,
    );

    final index = _habits.indexWhere((h) => h.localId == normalized.localId && h.localId != null);
    if (index >= 0) {
      _habits[index] = normalized;
    } else {
      _habits.add(normalized);
    }
  }

  Future<void> deleteHabit(int localId) async {
    _habits.removeWhere((h) => h.localId == localId);
  }

  Future<void> setArchived({required int localId, required bool archived}) async {
    final index = _habits.indexWhere((h) => h.localId == localId);
    if (index < 0) return;
    final habit = _habits[index];
    _habits[index] = UserHabit(
      localId: habit.localId,
      id: habit.id,
      name: habit.name,
      description: habit.description,
      goalName: habit.goalName,
      frequencyText: habit.frequencyText,
      reminderText: habit.reminderText,
      isArchived: archived,
      lastModified: DateTime.now().toUtc(),
    );
  }
}
