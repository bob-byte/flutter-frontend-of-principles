class SyncHandlerType {
  SyncHandlerType._();

  static const user = 'User';
  static const userGoal = 'UserGoal';
  static const userHabit = 'UserHabit';
  static const progressOfHabit = 'ProgressOfHabit';
  static const reminder = 'Reminder';
  static const task = 'Task';

  static const drainOrder = <String>[
    user,
    userGoal,
    userHabit,
    progressOfHabit,
    reminder,
    task,
  ];

  static int orderOf(String handlerType) {
    final index = drainOrder.indexOf(handlerType);
    return index < 0 ? 999 : index;
  }
}
