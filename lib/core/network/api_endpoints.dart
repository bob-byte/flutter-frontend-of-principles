class ApiEndpoints {
  ApiEndpoints._();

  static const account = '/account';
  static const simpleAuthorization = '$account/simpleauthorization';
  static const authorization = '$account/authorization';
  static const profile = '/profile';
  static const profileName = '$profile/name';
  static const profileMainSlogan = '$profile/mainslogan';
  static const profileMission = '$profile/mission';
  static const profileGender = '$profile/gender';
  static const profileRoadGuide = '$profile/roadguide';
  static const tasks = '/tasks';
  static const aiParseTask = '/ai/parse-task';
  static const aiChat = '/ai/chat';
  static const aiRecommendHabits = '/ai/recommend-habits';
  static const reminder = '/reminder';
  static const habitsReportReminder = '$reminder/habitsreport';
  static const allReminders = '$reminder/all';
  static const logs = '/logs';
  static const goals = '/goals';
  static const habits = '/habits';
  static const habitsInProgress = '$habits/inprogress';
  static const habitsArchive = '$habits/archive';
  static const habitArchiveStatus = '$habits/archivestatus';
  static const progressesOfHabit = '/progressesofhabit';
  static const sync = '/sync';
  static const syncPing = '$sync/ping';
  static const syncBootstrap = '$sync/bootstrap';
}
