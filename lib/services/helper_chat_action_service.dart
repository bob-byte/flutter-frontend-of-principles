import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/ai_task_draft.dart';
import '../models/habit.dart';
import '../models/helper_chat_action.dart';
import '../models/user_goal.dart';
import 'database_service.dart';
import 'goal_service.dart';
import 'habit_service.dart';
import 'user_service.dart';

enum HelperChatActionApplyKind {
  created,
  openedDraft,
  updated,
  alreadyExists,
  empty,
}

class HelperChatActionApplyResult {
  const HelperChatActionApplyResult({required this.kind, this.taskDraft});

  final HelperChatActionApplyKind kind;

  /// When [kind] is [HelperChatActionApplyKind.openedDraft], open the task sheet.
  final AiTaskDraft? taskDraft;
}

/// Creates goals/habits and updates mission/slogan from helper chat action chips.
class HelperChatActionService {
  HelperChatActionService({
    required GoalService goalService,
    required HabitService habitService,
    required DatabaseService database,
    required UserService userService,
  }) : _goalService = goalService,
       _habitService = habitService,
       _database = database,
       _userService = userService;

  final GoalService _goalService;
  final HabitService _habitService;
  final DatabaseService _database;
  final UserService _userService;

  Future<HelperChatActionApplyResult> apply(HelperChatAction action) async {
    final title = action.title.trim();
    if (title.isEmpty) {
      return const HelperChatActionApplyResult(
        kind: HelperChatActionApplyKind.empty,
      );
    }

    switch (action.type) {
      case HelperChatActionType.goal:
        return _addGoal(title, action.notes ?? action.reason);
      case HelperChatActionType.habit:
        return _addHabit(action);
      case HelperChatActionType.task:
        return HelperChatActionApplyResult(
          kind: HelperChatActionApplyKind.openedDraft,
          taskDraft: AiTaskDraft(
            title: title,
            description: (action.notes ?? action.reason).trim(),
          ),
        );
      case HelperChatActionType.mission:
        await _userService.saveMission(title);
        return const HelperChatActionApplyResult(
          kind: HelperChatActionApplyKind.updated,
        );
      case HelperChatActionType.slogan:
        await _userService.saveMainSlogan(title);
        return const HelperChatActionApplyResult(
          kind: HelperChatActionApplyKind.updated,
        );
    }
  }

  Future<HelperChatActionApplyResult> _addGoal(
    String name,
    String notes,
  ) async {
    // Include archived so a soft-hidden goal still blocks a duplicate name.
    final existing = await _goalService.getGoals(isArchived: null);
    final taken = existing.any(
      (g) => g.name.trim().toLowerCase() == name.toLowerCase(),
    );
    if (taken) {
      return const HelperChatActionApplyResult(
        kind: HelperChatActionApplyKind.alreadyExists,
      );
    }
    await _goalService.saveGoal(UserGoal(name: name, notes: notes.trim()));
    return const HelperChatActionApplyResult(
      kind: HelperChatActionApplyKind.created,
    );
  }

  Future<HelperChatActionApplyResult> _addHabit(HelperChatAction action) async {
    final name = action.title.trim();
    final habits = await _database.getAllHabits(isArchived: false);
    final taken = habits.any(
      (h) => h.name.trim().toLowerCase() == name.toLowerCase(),
    );
    if (taken) {
      return const HelperChatActionApplyResult(
        kind: HelperChatActionApplyKind.alreadyExists,
      );
    }

    String targetGoal = '';
    int? targetGoalId;
    final goalHint = action.goalName?.trim();
    if (goalHint != null && goalHint.isNotEmpty) {
      // Include archived so habit chips can still resolve a parent by name.
      final goals = await _goalService.getGoals(isArchived: null);
      UserGoal? match;
      for (final g in goals) {
        if (g.name.trim().toLowerCase() == goalHint.toLowerCase()) {
          // Prefer an active goal if an archived duplicate name somehow exists.
          if (match == null || (!g.isArchived && match.isArchived)) {
            match = g;
          }
        }
      }
      if (match != null) {
        targetGoal = match.name;
        targetGoalId = match.id ?? match.localId;
      } else {
        targetGoal = goalHint;
      }
    }

    final habit = Habit(
      name: name,
      notes: (action.notes ?? action.reason).trim(),
      targetGoal: targetGoal,
      targetGoalId: targetGoalId,
    );
    final id = await _database.insertHabit(habit);
    final stored = habit.copyWith(id: id);
    unawaited(
      _habitService.pushHabit(stored, isNew: true).catchError((Object e) {
        debugPrint('Push helper habit failed: $e');
        return null;
      }),
    );
    return const HelperChatActionApplyResult(
      kind: HelperChatActionApplyKind.created,
    );
  }
}
