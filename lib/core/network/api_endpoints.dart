class ApiEndpoints {
  ApiEndpoints._();

  static const account = '/account';
  static const simpleAuthorization = '$account/simpleauthorization';
  static const authorization = '$account/authorization';
  static const apiKey = '$account/apikey';
  static const profile = '/profile';
  static const profileName = '$profile/name';
  static const profileMainSlogan = '$profile/mainslogan';
  static const profileMission = '$profile/mission';
  static const tasks = '/tasks';
  static const aiParseTask = '/ai/parse-task';
  static const aiChat = '/ai/chat';
}
