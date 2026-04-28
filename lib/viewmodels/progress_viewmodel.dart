import 'package:flutter/foundation.dart';

import '../models/progress_of_habit.dart';
import '../services/progress_service.dart';

class ProgressViewModel extends ChangeNotifier {
  ProgressViewModel(this._progressService);

  final ProgressService _progressService;
  final List<ProgressOfHabit> items = [];
  bool isLoading = false;

  Future<void> load() async {
    isLoading = true;
    notifyListeners();
    try {
      final data = await _progressService.getProgresses();
      items
        ..clear()
        ..addAll(data);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addProgress(int value) async {
    await _progressService.saveProgress(
      ProgressOfHabit(
        userHabitLocalId: 1,
        dateAsInt: DateTime.now().millisecondsSinceEpoch ~/ Duration.millisecondsPerDay,
        value: value,
      ),
    );
    await load();
  }
}
