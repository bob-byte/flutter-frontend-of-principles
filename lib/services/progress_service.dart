import '../models/progress_of_habit.dart';

class ProgressService {
  final List<ProgressOfHabit> _items = [];

  Future<List<ProgressOfHabit>> getProgresses() async => List.unmodifiable(_items);

  Future<void> saveProgress(ProgressOfHabit progress) async {
    _items.add(progress);
  }
}
