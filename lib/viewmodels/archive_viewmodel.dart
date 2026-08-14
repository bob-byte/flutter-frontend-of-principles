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
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenBanner = prefs.getBool('hasSeenArchiveInfo') ?? false;
    showInfoBanner = !hasSeenBanner;
    await loadHabits();
  }

  Future<void> loadHabits() async {
    isLoading = true;
    notifyListeners();

    archivedHabits = await _dbService.getAllHabits(isArchived: true);
    
    isLoading = false;
    notifyListeners();
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
    _habitService.pushHabit(updatedHabit).catchError((e) {
      debugPrint('Failed to sync unarchive: $e');
    });
  }

  Future<void> deleteHabit(Habit habit) async {
    if (habit.id != null) {
      // Local delete
      await _dbService.deleteHabit(habit.id!);
      archivedHabits.removeWhere((h) => h.id == habit.id);
      notifyListeners();
      
      // We would also need to delete from backend, 
      // but HabitService might need a deleteHabit method if it doesn't exist.
    }
  }

  void close() {
    _dialogService.completeSheet(SheetResponse(confirmed: false));
  }
}
