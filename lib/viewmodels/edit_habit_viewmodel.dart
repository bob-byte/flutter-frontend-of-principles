import 'package:flutter/foundation.dart';

import '../models/habit.dart';
import '../services/database_service.dart';
import '../services/habit_service.dart';
import '../services/reminder_service.dart';
import '../services/goal_service.dart';
import '../models/frequency_config.dart';
import '../models/user_goal.dart';
import '../models/habit_reminder.dart';
import '../models/area_of_life.dart';
import '../services/dialog_service.dart';

class EditHabitViewModel extends ChangeNotifier {
  EditHabitViewModel(this._habitService, this._reminderService, this._goalService);

  final HabitService _habitService;
  final ReminderService _reminderService;
  final GoalService _goalService;
  final DatabaseService _dbService = DatabaseService();
  final DialogService _dialogService = DialogService();

  int? editingHabitId;

  void init(Habit? habit) {
    if (habit != null) {
      editingHabitId = habit.id;
      habitName = habit.name;
      targetGoal = habit.targetGoal ?? '';
      targetGoalId = habit.targetGoalId;
      isFlexible = habit.isFlexible;
      frequency = habit.frequency ?? const FrequencyConfig(type: FrequencyType.daily);
      reminders = List.from(habit.reminders ?? []);
      notes = habit.notes ?? '';
      difficulty = habit.difficulty ?? 5;
      selectedAreas = List.from(habit.areasOfLife ?? []);
      if (selectedAreas.isEmpty) {
        selectedAreas.add(allAreasFakeItem);
      }
    } else {
      editingHabitId = null;
      habitName = '';
      targetGoal = '';
      targetGoalId = null;
      isFlexible = true;
      frequency = const FrequencyConfig(type: FrequencyType.daily);
      reminders = [];
      notes = '';
      difficulty = 5;
      selectedAreas = [allAreasFakeItem];
    }
  }

  final List<AreaOfLife> allAreas = [
    allAreasFakeItem,
    const AreaOfLife(id: 1, name: 'Spirituality'),
    const AreaOfLife(id: 2, name: 'Character'),
    const AreaOfLife(id: 3, name: 'Mentality'),
    const AreaOfLife(id: 4, name: 'Health'),
    const AreaOfLife(id: 5, name: 'Career'),
    const AreaOfLife(id: 6, name: 'Household chores'),
    const AreaOfLife(id: 7, name: 'Family'),
    const AreaOfLife(id: 8, name: 'Relationships'),
    const AreaOfLife(id: 9, name: 'Sociality'),
    const AreaOfLife(id: 10, name: 'Other'),
  ];

  List<AreaOfLife> selectedAreas = [];

  void toggleArea(AreaOfLife area) {
    if (selectedAreas.contains(area)) {
      selectedAreas.remove(area);
      if (selectedAreas.isEmpty) {
        selectedAreas.add(allAreasFakeItem);
      }
    } else {
      if (area.id == 0) {
        selectedAreas.clear();
        selectedAreas.add(area);
      } else {
        selectedAreas.removeWhere((a) => a.id == 0);
        selectedAreas.add(area);
      }
    }
    notifyListeners();
  }

  Future<void> requestAreaSelection() async {
    final response = await _dialogService.showCustomSheet(
      variant: BottomSheetType.areaSelection,
      data: selectedAreas,
    );

    if (response != null && response.confirmed == true) {
      selectedAreas = List.from(response.data as List<AreaOfLife>);
      if (selectedAreas.isEmpty) {
        selectedAreas.add(allAreasFakeItem);
      }
      notifyListeners();
    }
  }

  // Вкладка 1 (Дані)
  String habitName = '';
  String targetGoal = '';
  int? targetGoalId;
  bool isFlexible = true;
  FrequencyConfig frequency = const FrequencyConfig(type: FrequencyType.daily);
  List<HabitReminder> reminders = [];

  // Вкладка 2 (Як утримувати)
  String notes = '';
  int difficulty = 5;

  bool isSaving = false;

  void setFlexible(bool value) {
    if (isFlexible != value) {
      isFlexible = value;
      notifyListeners();
    }
  }

  void setTargetGoal(UserGoal goal) {
    if (targetGoalId != goal.id || targetGoal != goal.name) {
      targetGoal = goal.name;
      targetGoalId = goal.id ?? goal.localId; // Use backend ID if available, else local ID
      notifyListeners();
    }
  }

  Future<void> requestGoalSelection() async {
    final response = await _dialogService.showCustomSheet(
      variant: BottomSheetType.goalSelection,
      data: targetGoal, // Currently selected string for UI highlight
    );

    if (response != null && response.confirmed == true) {
      final selectedGoal = response.data as UserGoal;
      setTargetGoal(selectedGoal);
    }
  }

  void setFrequency(FrequencyConfig freq) {
    if (frequency != freq) {
      frequency = freq;
      notifyListeners();
    }
  }

  Future<void> requestFrequencyConfig() async {
    final response = await _dialogService.showCustomDialog(
      variant: DialogType.frequencyConfig,
      data: frequency,
    );

    if (response != null && response.confirmed == true) {
      setFrequency(response.data as FrequencyConfig);
    }
  }

  void setReminder(HabitReminder? reminder) {
    if (reminder != null) {
      if (reminders.isNotEmpty) {
        reminders[0] = reminder;
      } else {
        reminders.add(reminder);
      }
      notifyListeners();
    }
  }

  void incrementDifficulty() {
    if (difficulty < 10) {
      difficulty++;
      notifyListeners();
    }
  }

  void decrementDifficulty() {
    if (difficulty > 1) {
      difficulty--;
      notifyListeners();
    }
  }

  Future<bool> saveHabit() async {
    if (habitName.trim().isEmpty) return false;
    
    isSaving = true;
    notifyListeners();
    
    try {
      final newHabit = Habit(
        id: editingHabitId,
        name: habitName,
        targetGoal: targetGoal,
        targetGoalId: targetGoalId,
        isFlexible: isFlexible,
        frequency: frequency,
        reminders: reminders,
        areasOfLife: selectedAreas.where((a) => a.id != 0).toList(),
        difficulty: difficulty,
        notes: notes,
      );
      
      if (editingHabitId == null) {
        final id = await _dbService.insertHabit(newHabit);
        final savedHabit = newHabit.copyWith(id: id);
        
        // Push to backend (Fire and forget, don't wait for network)
        _habitService.pushHabit(savedHabit).catchError((e) {
          debugPrint('Backend sync failed, but saved locally: $e');
        });
      } else {
        await _dbService.updateHabit(newHabit);
        _habitService.pushHabit(newHabit).catchError((e) {
          debugPrint('Backend sync failed, but saved locally: $e');
        });
      }
      
      return true;
    } catch (e) {
      debugPrint('Save habit error: $e');
      return false;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }
}
