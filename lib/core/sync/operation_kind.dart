class OperationKind {
  OperationKind._();

  static const save = 'Save';
  static const delete = 'Delete';
  static const saveUserName = 'SaveUserName';
  static const saveMainSlogan = 'SaveMainSlogan';
  static const saveMission = 'SaveMission';
  static const saveGender = 'SaveGender';
  static const saveHasSeenRoadGuide = 'SaveHasSeenRoadGuide';
  static const setArchiveStatus = 'SetArchiveStatus';
  static const updateStatus = 'UpdateStatus';

  static String normalize(String operation) {
    final trimmed = operation.trim();
    if (trimmed.isEmpty) return trimmed;
    return '${trimmed[0].toUpperCase()}${trimmed.substring(1)}';
  }

  static bool isDelete(String operation) =>
      normalize(operation) == delete;
}
