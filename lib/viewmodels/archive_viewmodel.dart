import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/habit.dart';
import '../services/database_service.dart';
import '../services/habit_service.dart';
import '../services/dialog_service.dart';

class ArchiveViewModel extends ChangeNotifier {
  final DatabaseService _dbService;
  final HabitService _habitService;
  final DialogService _dialogService = DialogService();

  List<Habit> archivedHabits = [];
  bool isLoading = true;
  bool showInfoBanner = false;

  ArchiveViewModel(this._dbService, this._habitService) {
    loadHabits();
  }

  Future<void> loadHabits() async {
    isLoading = true;
    notifyListeners();

    try {
      archivedHabits = await _dbService.getAllHabits(isArchived: true);
      if (archivedHabits.isNotEmpty) {
        isLoading = false;
        notifyListeners();
      }

      archivedHabits = await _habitService.getArchivedHabits();
    } catch (e) {
      debugPrint('Failed to load archived habits: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> hideBanner() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenArchiveInfo', true);
    showInfoBanner = false;
    notifyListeners();
  }

  void showBanner() {
    showInfoBanner = true;
    notifyListeners();
  }

  Future<void> unarchiveHabit(Habit habit) async {
    final updatedHabit = habit.copyWith(isArchived: false);

    // Optimistic local update
    await _dbService.updateHabit(updatedHabit);
    archivedHabits.removeWhere((h) => h.id == habit.id);
    notifyListeners();

    // Background push
    _habitService.setArchiveStatus(updatedHabit).catchError((e) {
      debugPrint('Failed to sync unarchive: $e');
      return false;
    });
  }

  Future<bool> deleteHabit(Habit habit) async {
    final habitId = habit.id;
    if (habitId == null) return false;

    final deletedRemotely = await _habitService.deleteHabit(
      habitId,
      serverId: confirmedServerHabitId(habit),
    );
    if (!deletedRemotely) return false;

    await _dbService.deleteHabit(habitId);
    archivedHabits.removeWhere((h) => h.id == habitId);
    notifyListeners();
    return true;
  }

  void close() {
    _dialogService.completeSheet(SheetResponse(confirmed: false));
  }
}
