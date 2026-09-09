import '../home_widget/home_widget_link.dart';
import '../utils/date_helpers.dart';

/// Pending in-app destination from a home-widget tap or local notification.
enum DeepLinkKind {
  homeWidget,
  openTask,
  openHabitDetail,
  openHabitsTab,
  openTasksTab,
}

class DeepLinkAction {
  const DeepLinkAction._({
    required this.kind,
    this.taskId,
    this.habitId,
    this.day,
    this.openCreate = false,
    this.openToday = false,
  });

  const DeepLinkAction.openTask(String taskId)
    : this._(kind: DeepLinkKind.openTask, taskId: taskId);

  const DeepLinkAction.openHabitDetail(int habitId)
    : this._(kind: DeepLinkKind.openHabitDetail, habitId: habitId);

  const DeepLinkAction.openHabitsTab()
    : this._(kind: DeepLinkKind.openHabitsTab);

  /// Daily progress reminder — Tasks today (tasks + habits hub).
  const DeepLinkAction.openTasksTab({bool openToday = true})
    : this._(kind: DeepLinkKind.openTasksTab, openToday: openToday);

  factory DeepLinkAction.homeWidget(HomeWidgetLaunchAction action) {
    return DeepLinkAction._(
      kind: DeepLinkKind.homeWidget,
      day: action.day == null ? null : dateOnly(action.day!),
      openCreate: action.openCreate,
      openToday: action.openToday,
    );
  }

  final DeepLinkKind kind;
  final String? taskId;
  final int? habitId;
  final DateTime? day;
  final bool openCreate;
  final bool openToday;

  bool get isEmpty {
    return switch (kind) {
      DeepLinkKind.homeWidget => day == null && !openCreate && !openToday,
      DeepLinkKind.openTask => taskId == null || taskId!.isEmpty,
      DeepLinkKind.openHabitDetail => habitId == null,
      DeepLinkKind.openHabitsTab => false,
      DeepLinkKind.openTasksTab => false,
    };
  }
}
