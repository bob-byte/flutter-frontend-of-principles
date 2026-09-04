import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/habit_score.dart';
import '../l10n/app_localizations.dart';
import '../models/habit.dart';
import '../models/recommended_habit.dart';
import '../services/database_service.dart';
import '../services/habit_service.dart';
import '../services/reminder_service.dart';
import '../services/goal_service.dart';
import '../models/frequency_config.dart';
import '../models/user_goal.dart';
import '../models/habit_reminder.dart';
import '../models/schedule_reminder_offset.dart';
import '../services/ai_recommendation_service.dart';
import '../services/dialog_service.dart';
import '../services/user_service.dart';
import '../viewmodels/schedule_draft.dart';

class EditHabitViewModel extends ChangeNotifier {
  EditHabitViewModel(
    this._habitService,
    this._reminderService,
    this._goalService,
    this._aiRecommendationService,
    this._userService, {
    DatabaseService? dbService,
  }) : _dbService = dbService ?? DatabaseService();

  final HabitService _habitService;
  final ReminderService _reminderService;
  final GoalService _goalService;
  final AiRecommendationService _aiRecommendationService;
  final UserService _userService;
  final DatabaseService _dbService;
  final DialogService _dialogService = DialogService();

  int? editingHabitId;
  List<HabitProgressMark> _progressMarks = [];
  bool _shouldReloadRecommendedHabits = true;

  void init(Habit? habit) {
    if (habit != null) {
      editingHabitId = habit.id;
      habitName = habit.name;
      targetGoal = habit.targetGoal;
      targetGoalId = habit.targetGoalId;
      isFlexible = habit.isFlexible;
      frequency = habit.frequency;
      reminders = List.from(habit.reminders);
      notes = habit.notes;
      difficulty = habit.difficulty;
      endDate = habit.endDate;
      allDay = habit.allDay;
      constantReminder = habit.constantReminder;
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
      endDate = null;
      allDay = false;
      constantReminder = false;
    }
    _progressMarks = [];
    recommendedHabits = [];
    isRecommendedHabitsLoading = false;
    recommendedHabitsError = null;
    _shouldReloadRecommendedHabits = true;
    final habitId = habit?.id;
    if (habitId != null) {
      _loadProgress(habitId);
    }
  }

  Future<void> _loadProgress(int habitId) async {
    try {
      final records = await _dbService.getAllRecordsForHabit(habitId);
      if (editingHabitId != habitId) return;
      _progressMarks = [
        for (final record in records)
          HabitProgressMark(date: record.date, value: record.value),
      ];
      notifyListeners();
    } catch (e) {
      debugPrint('Load habit progress error: $e');
    }
  }

  bool get isNewHabit => editingHabitId == null;

  /// MAUI [ComplexityToHelpTextConverter] label under difficulty.
  String automationHelpText(AppLocalizations l10n, {DateTime? now}) {
    if (isNewHabit) {
      return formatHabitAutomationHelpText(
        l10n: l10n,
        isNewHabit: true,
        days: daysCountForComplexity(difficulty),
      );
    }
    try {
      return formatHabitAutomationHelpText(
        l10n: l10n,
        isNewHabit: false,
        days: getDaysUntilFullAutomation(
          marks: _progressMarks,
          frequency: frequency,
          complexity: difficulty,
          now: now,
        ),
      );
    } catch (_) {
      return '';
    }
  }

  // Вкладка 1 (Дані)
  String habitName = '';
  String targetGoal = '';
  int? targetGoalId;
  bool isFlexible = true;
  FrequencyConfig frequency = const FrequencyConfig(type: FrequencyType.daily);
  List<HabitReminder> reminders = [];
  DateTime? endDate;
  bool allDay = false;
  bool constantReminder = false;

  // Вкладка 2 (Як утримувати)
  String notes = '';
  int difficulty = 5;

  bool isSaving = false;
  List<RecommendedHabit> recommendedHabits = [];
  bool isRecommendedHabitsLoading = false;
  String? recommendedHabitsError;

  void setFlexible(bool value) {
    if (isFlexible != value) {
      isFlexible = value;
      notifyListeners();
    }
  }

  void setTargetGoal(UserGoal goal) {
    if (targetGoalId != goal.id || targetGoal != goal.name) {
      targetGoal = goal.name;
      targetGoalId =
          goal.id ?? goal.localId; // Use backend ID if available, else local ID
      _shouldReloadRecommendedHabits = true;
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

  void applySchedule(ScheduleDraft draft) {
    // Habits use Frequency for recurrence; schedule is time + reminder offsets.
    // Times can differ by weekday via multiple HabitTimeSlots.
    endDate = null;
    allDay = false;

    final slots = [
      for (final slot in draft.habitTimeSlots)
        if (slot.weekdays.isNotEmpty) slot,
    ];
    if (draft.isEmpty ||
        (slots.isEmpty && !draft.hasTime && draft.reminders.isEmpty)) {
      reminders = [];
      constantReminder = false;
      notifyListeners();
      return;
    }

    final existing = List<HabitReminder>.from(reminders);

    WeekDay weekdayFor(int type) {
      for (final reminder in existing) {
        for (final day in reminder.daysOfWeek) {
          if (day.type == type) return day;
        }
      }
      return WeekDay(
        type: type,
        userNotificationRequestId: _reminderService.allocateNotificationId(),
      );
    }

    int offsetId(
      int slotIndex,
      HabitReminder? previous,
      ScheduleReminderOffset offset,
    ) {
      if (previous != null) {
        for (final e in previous.offsets) {
          if (e.offsetMinutes == offset.offsetMinutes &&
              e.notificationRequestId != null) {
            return e.notificationRequestId!;
          }
        }
      }
      if (slotIndex == 0 && offset.notificationRequestId != null) {
        return offset.notificationRequestId!;
      }
      return _reminderService.allocateNotificationId();
    }

    final title = habitName.trim().isEmpty ? 'Reminder' : habitName;
    final built = <HabitReminder>[];
    for (var i = 0; i < slots.length; i++) {
      final slot = slots[i];
      final previous = i < existing.length ? existing[i] : null;
      final days = [
        for (final d in (slot.weekdays.toList()..sort())) weekdayFor(d),
      ];
      built.add(
        HabitReminder(
          id: previous?.id,
          title: (previous?.title.trim().isNotEmpty ?? false)
              ? previous!.title
              : title,
          description: previous?.description ?? '',
          time: slot.time,
          isEnabled: true,
          daysOfWeek: days,
          offsets: [
            for (final offset in draft.reminders)
              ScheduleReminderOffset(
                offsetMinutes: offset.offsetMinutes,
                notificationRequestId: offsetId(i, previous, offset),
              ),
          ],
          constantReminder: draft.constantReminder,
          constantNotificationRequestId:
              previous?.constantNotificationRequestId,
          allDay: false,
        ),
      );
    }
    reminders = built;
    constantReminder = draft.constantReminder;
    notifyListeners();
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

  Future<bool> requestRecommendedHabits({required String culture}) async {
    if (!isNewHabit) return false;
    if (isRecommendedHabitsLoading) return true;

    final needsLoad =
        _shouldReloadRecommendedHabits || recommendedHabits.isEmpty;
    if (needsLoad) {
      final confirmed = await _dialogService.showConfirmAsync(
        title: _dialogService.l10n.confirmRecommendedHabitsTitle,
        msg: _dialogService.l10n.confirmRecommendedHabitsMessage,
      );
      if (!confirmed) return false;
      _loadRecommendedHabits(culture: culture);
    }
    return true;
  }

  Future<void> _loadRecommendedHabits({required String culture}) async {
    isRecommendedHabitsLoading = true;
    recommendedHabitsError = null;
    notifyListeners();

    try {
      final user = await _userService.getCurrentUser();
      final habits = await _dbService.getAllHabits();
      final goals = await _goalService.getGoals();
      final result = await _aiRecommendationService.recommendHabits(
        culture: culture,
        currentHabits: [
          for (final habit in habits)
            if (habit.name.trim().isNotEmpty) habit.name.trim(),
        ],
        goals: [
          for (final goal in goals)
            if (goal.name.trim().isNotEmpty) goal.name.trim(),
        ],
        mission: user.mission,
        slogan: user.mainSlogan,
        goal: targetGoal.trim().isEmpty ? null : targetGoal.trim(),
        gender: user.gender,
      );
      recommendedHabits = result;
      _shouldReloadRecommendedHabits = false;
    } catch (e) {
      recommendedHabitsError = e.toString().replaceFirst(
        RegExp(r'^Bad state:\s*'),
        '',
      );
      debugPrint('Recommend habits error: $e');
    } finally {
      isRecommendedHabitsLoading = false;
      notifyListeners();
    }
  }

  void applyRecommendedHabit(RecommendedHabit recommendedHabit) {
    habitName = recommendedHabit.name;
    final reason = recommendedHabit.reasonToFollow.trim();
    if (reason.isEmpty) {
      notifyListeners();
      return;
    }
    if (notes.trim().isEmpty) {
      notes = reason;
    } else {
      notes = '$notes\n\n$reason';
    }
    notifyListeners();
  }

  Future<bool> saveHabit() async {
    habitName = habitName.trim();
    notes = notes.trim();
    if (habitName.isEmpty) return false;

    final wantsNotifications =
        constantReminder || reminders.any((reminder) => reminder.isEnabled);
    if (wantsNotifications) {
      final allowed = await _reminderService.requestAccessToSendNotifications();
      if (!allowed) {
        await _dialogService.promptOpenNotificationSettings();
      }
    }

    isSaving = true;
    notifyListeners();

    try {
      final isNew = editingHabitId == null;
      final newHabit = Habit(
        id: editingHabitId,
        name: habitName,
        targetGoal: targetGoal,
        targetGoalId: targetGoalId,
        isFlexible: isFlexible,
        frequency: frequency,
        difficulty: difficulty,
        notes: notes,
        reminders: reminders,
        endDate: endDate,
        allDay: allDay,
        constantReminder: constantReminder,
      );

      var localId = editingHabitId;
      if (isNew) {
        localId = await _dbService.insertHabit(newHabit);
      } else {
        await _dbService.updateHabit(newHabit);
      }

      final savedHabit = newHabit.copyWith(id: localId);
      unawaited(
        _habitService.pushHabit(savedHabit, isNew: isNew).catchError((
          Object e,
        ) {
          debugPrint('Backend sync failed, but saved locally: $e');
          return null;
        }),
      );
      unawaited(
        _reminderService.syncHabitNotifications(savedHabit).catchError((
          Object e,
        ) {
          debugPrint('Habit notification sync failed: $e');
        }),
      );

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

@visibleForTesting
String formatHabitAutomationHelpText({
  required AppLocalizations l10n,
  required bool isNewHabit,
  required int days,
}) {
  if (isNewHabit) {
    return l10n.habitAutomationExplanation(days);
  }
  if (days == 0) return l10n.habitAlreadyAutomated;
  if (days < 30) return l10n.habitDaysToGoUntilAutomaticJust(days);
  return l10n.habitDaysToGoUntilAutomaticStill(days);
}
