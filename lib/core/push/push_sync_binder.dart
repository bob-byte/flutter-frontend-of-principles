import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../services/database_service.dart';
import '../../services/push_sync_service.dart';
import '../../services/reminder_service.dart';
import '../../services/task_service.dart';
import '../../viewmodels/goals_viewmodel.dart';
import '../../viewmodels/habit_progress_viewmodel.dart';
import '../../viewmodels/tasks_viewmodel.dart';
import '../launch_data_loader.dart';
import '../road_guide/road_guide_controller.dart';
import '../sync/sync_run_result.dart';
import '../sync/sync_trigger.dart';
import 'sync_push_message.dart';

/// While the signed-in shell is mounted, a silent sync push cancels the
/// deleted rows' reminders, drops them from local SQLite immediately, then
/// pulls `/sync/changes` for everything else.
class PushSyncBinder extends StatefulWidget {
  const PushSyncBinder({super.key, required this.child});

  final Widget child;

  @override
  State<PushSyncBinder> createState() => _PushSyncBinderState();
}

class _PushSyncBinderState extends State<PushSyncBinder> {
  PushSyncService? _push;
  ReminderService? _reminders;
  LaunchDataLoader? _loader;
  RoadGuideController? _guide;
  TaskService? _tasks;
  DatabaseService? _db;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !PushSyncService.isReady) return;
      try {
        _push = context.read<PushSyncService>();
        _reminders = context.read<ReminderService>();
        _loader = context.read<LaunchDataLoader>();
        _tasks = context.read<TaskService>();
        _db = context.read<DatabaseService>();
      } on ProviderNotFoundException {
        return;
      }
      try {
        _guide = context.read<RoadGuideController>();
      } on ProviderNotFoundException {
        // Widget tests may omit the guide.
      }
      _push!.attach(_onPush);
    });
  }

  @override
  void dispose() {
    _push?.detach();
    super.dispose();
  }

  Future<void> _onPush(SyncPushMessage push) async {
    await _reminders?.cancelRemoteDeletedReminders(
      taskIds: push.deletedTaskIds,
      habitIds: push.deletedHabitIds,
    );
    // Drop deleted rows before /sync/changes so the UI updates even when the
    // pull is skipped (road guide) or the cursor races the tombstone.
    await _applyPushDeletes(push);
    // Bootstrap merge during the road guide freezes the spotlight.
    if (_guide?.isActive ?? false) return;
    final loader = _loader;
    if (loader == null) return;
    final result = await loader.syncAndHydrate(SyncTrigger.remotePush);
    // A pull already in flight may have started before this change landed.
    if (result.status == SyncRunStatus.skippedAlreadyRunning) {
      await loader.syncAndHydrate(SyncTrigger.remotePush);
    }
  }

  Future<void> _applyPushDeletes(SyncPushMessage push) async {
    if (push.deletedTaskIds.isEmpty && push.deletedHabitIds.isEmpty) return;
    try {
      // The follow-up merge no longer sees these rows, so cancel by their
      // stored notification ids here.
      for (final id in push.deletedTaskIds) {
        for (final task in await _tasks?.discardRemoteDeletedTask(id) ?? []) {
          await _reminders?.cancelTaskNotifications(task);
        }
      }
      if (push.deletedHabitIds.isNotEmpty) {
        final habits = await _db?.deleteHabitsByServerIds(push.deletedHabitIds);
        for (final habit in habits ?? const []) {
          await _reminders?.cancelHabitNotifications(habit);
        }
      }
    } catch (_) {
      // Sync catch-up below still applies tombstones.
    }
    if (!mounted) return;
    try {
      await Future.wait([
        context.read<TasksViewModel>().load(silent: true),
        context.read<HabitProgressViewModel>().load(
          silent: true,
          syncRemote: false,
        ),
        context.read<GoalsViewModel>().load(silent: true),
      ]);
    } on ProviderNotFoundException {
      // Widget tests may omit tab VMs.
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
