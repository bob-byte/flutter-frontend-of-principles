import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/habit.dart';
import '../models/habit_record.dart';
import '../models/frequency_config.dart';
import '../services/database_service.dart';
import '../services/habit_service.dart';

class ProgressViewModel extends ChangeNotifier {
  ProgressViewModel(this._habitService) {
    selectedDate = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  }

  final HabitService _habitService;
  final DatabaseService _dbService = DatabaseService();
  
  bool isLoading = false;
  
  List<Habit> habits = [];
  List<HabitRecord> records = [];
  
  // генеруємо останні 14 днів для відображення
  List<DateTime> dates = List.generate(14, (index) => 
    DateTime.now().subtract(Duration(days: 13 - index))
  );

  late DateTime selectedDate;

  void selectDate(DateTime date) {
    selectedDate = DateTime(date.year, date.month, date.day);
    notifyListeners();
  }

  int currentStreak = 0;

  Future<void> load({bool silent = false}) async {
    if (!silent && habits.isEmpty) {
      isLoading = true;
      notifyListeners();
    }

    try {
      // 1. Одразу завантажуємо локальні дані
      habits = await _dbService.getAllHabits(isArchived: false);
      final startDate = dates.first;
      final endDate = dates.last;
      records = await _dbService.getRecordsForDateRange(startDate, endDate);
      _calculateStreak();
      
      // Якщо в нас вже є локальні дані, відключаємо індикатор загрузки
      if (isLoading) {
        isLoading = false;
        notifyListeners();
      }

      // 2. Фонова синхронізація з бекендом
      await _habitService.syncFromBackend();

      // 3. Оновлюємо дані після фонової синхронізації
      habits = await _dbService.getAllHabits(isArchived: false);
      records = await _dbService.getRecordsForDateRange(startDate, endDate);
      _calculateStreak();
    } finally {
      if (isLoading) {
        isLoading = false;
        notifyListeners();
      }
      // Обов'язково сповіщаємо UI про можливі нові дані з фонової синхронізації
      notifyListeners();
    }
  }

  void _calculateStreak() {
    // Basic streak calculation logic
    currentStreak = 0; // TODO: implement real logic
  }

  int get completedHabitsCount {
    int count = 0;
    for (var habit in habits) {
      if (getStatusForHabitAndDate(habit.id ?? 0, selectedDate) == HabitStatus.completed) {
        count++;
      }
    }
    return count;
  }

  int get totalHabitsCount {
    return habits.length; // TODO: filter by habits that are scheduled for selectedDate
  }

  // Групуємо звички (наприклад, по reminderTime, але для простоти зараз єдиним списком)
  Map<String, List<Habit>> get groupedHabits {
    final map = <String, List<Habit>>{};
    
    // Сортуємо звички за часом перед групуванням
    final sortedHabits = List<Habit>.from(habits)..sort((a, b) {
      if (a.reminderTime == null && b.reminderTime == null) return 0;
      if (a.reminderTime == null) return 1;
      if (b.reminderTime == null) return -1;
      return a.reminderTime!.compareTo(b.reminderTime!);
    });

    for (var habit in sortedHabits) {
      // Показуємо час нагадування або "Весь день"
      final key = habit.reminderTime != null 
        ? DateFormat('HH:mm').format(habit.reminderTime!) 
        : "Весь день";
      if (!map.containsKey(key)) {
        map[key] = [];
      }
      map[key]!.add(habit);
    }
    return map;
  }

  HabitStatus getStatusForHabitAndDate(int habitId, DateTime date) {
    final dateString = date.toIso8601String().substring(0, 10);
    final record = records.where((r) => 
      r.habitId == habitId && r.date.toIso8601String().substring(0, 10) == dateString
    ).firstOrNull;
    
    return record?.status ?? HabitStatus.none;
  }

  double getWeeklyProgress(Habit habit, DateTime referenceDate) {
    if (habit.id == null) return 0.0;

    // Find start of week (Monday) and end of week (Sunday)
    int daysFromMonday = referenceDate.weekday - DateTime.monday;
    DateTime startOfWeek = referenceDate.subtract(Duration(days: daysFromMonday));
    DateTime endOfWeek = startOfWeek.add(const Duration(days: 6));

    final startStr = startOfWeek.toIso8601String().substring(0, 10);
    final endStr = endOfWeek.toIso8601String().substring(0, 10);

    // Count completions this week
    int completedCount = records.where((r) {
      if (r.habitId != habit.id || r.status != HabitStatus.completed) return false;
      final rDateStr = r.date.toIso8601String().substring(0, 10);
      return rDateStr.compareTo(startStr) >= 0 && rDateStr.compareTo(endStr) <= 0;
    }).length;

    // Determine target count for the week
    int target = 7;
    final freq = habit.frequency ?? const FrequencyConfig(type: FrequencyType.daily);
    
    if (freq.type == FrequencyType.daily) {
      target = 7;
    } else if (freq.type == FrequencyType.everyXDays) {
      target = (7 / (freq.interval ?? 1)).ceil();
    } else if (freq.type == FrequencyType.timesPerPeriod) {
      if (freq.period == PeriodType.week) {
        target = freq.interval ?? 1;
      } else {
        target = ((freq.interval ?? 1) / 4).ceil();
      }
    }
    
    if (target <= 0) target = 1; // safety check
    
    return (completedCount / target).clamp(0.0, 1.0);
  }

  Future<void> toggleHabitStatus(int habitId, DateTime date) async {
    final currentStatus = getStatusForHabitAndDate(habitId, date);
    
    HabitStatus nextStatus;
    if (currentStatus == HabitStatus.none) {
      nextStatus = HabitStatus.completed;
    } else if (currentStatus == HabitStatus.completed) {
      nextStatus = HabitStatus.skipped;
    } else {
      nextStatus = HabitStatus.none;
    }

    // Optimistic UI Update: update locally first
    final dateString = date.toIso8601String().substring(0, 10);
    
    // Remove old record if exists
    records.removeWhere((r) => 
      r.habitId == habitId && r.date.toIso8601String().substring(0, 10) == dateString
    );
    
    // Add new record if not none
    if (nextStatus != HabitStatus.none) {
      records.add(HabitRecord(
        habitId: habitId, 
        date: date, 
        status: nextStatus
      ));
    }
    
    notifyListeners();

    // Background update to DB
    await _dbService.setHabitRecordStatus(habitId, date, nextStatus);

    // Push to backend
    await _habitService.pushProgress(habitId, date, nextStatus);
  }

  Future<void> archiveHabit(Habit habit) async {
    final updatedHabit = habit.copyWith(isArchived: true);
    await _dbService.updateHabit(updatedHabit);
    habits.removeWhere((h) => h.id == habit.id);
    notifyListeners();

    _habitService.pushHabit(updatedHabit).catchError((e) {
      debugPrint('Failed to sync archive: $e');
    });
  }

  Future<void> deleteHabit(Habit habit) async {
    if (habit.id != null) {
      await _dbService.deleteHabit(habit.id!);
      habits.removeWhere((h) => h.id == habit.id);
      notifyListeners();
      // Assume backend also needs deletion if API supports it, but HabitService might not have it yet.
    }
  }
}
