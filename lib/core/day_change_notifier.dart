import 'dart:async';

import 'package:flutter/widgets.dart';

import 'utils/date_helpers.dart';

/// Fires when the local calendar day rolls over (MAUI day-change observer).
///
/// Schedules a timer until midnight and re-checks on [AppLifecycleState.resumed]
/// (same trigger as MAUI [App.OnResume] → [TryAddNewDayInHabitListMessage]).
class DayChangeNotifier extends ChangeNotifier with WidgetsBindingObserver {
  DayChangeNotifier({
    DateTime Function()? clock,
    bool observeLifecycle = true,
    bool scheduleTimer = true,
  }) : _clock = clock ?? DateTime.now {
    _today = dateOnly(_clock());
    if (observeLifecycle) {
      WidgetsBinding.instance.addObserver(this);
      _observingLifecycle = true;
    }
    if (scheduleTimer) {
      _scheduleNextMidnight();
    }
  }

  final DateTime Function() _clock;
  bool _observingLifecycle = false;
  Timer? _timer;
  late DateTime _today;

  /// Last observed local calendar day.
  DateTime get today => _today;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      checkForDayChange();
    }
  }

  /// Re-check the calendar day (midnight timer, resume, or tests).
  ///
  /// Returns true when [today] advanced and listeners were notified.
  bool checkForDayChange() {
    final next = dateOnly(_clock());
    if (isSameDay(next, _today)) return false;
    _today = next;
    notifyListeners();
    return true;
  }

  void _scheduleNextMidnight() {
    _timer?.cancel();
    final delay = timeUntilMidnight(_clock());
    // Guard against zero/negative if the clock jumps; fire ASAP then reschedule.
    final due = delay <= Duration.zero
        ? const Duration(milliseconds: 1)
        : delay;
    _timer = Timer(due, () {
      checkForDayChange();
      _scheduleNextMidnight();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    if (_observingLifecycle) {
      WidgetsBinding.instance.removeObserver(this);
      _observingLifecycle = false;
    }
    super.dispose();
  }
}
