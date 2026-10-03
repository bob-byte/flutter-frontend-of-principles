class ChatMessage {
  ChatMessage({
    required this.text,
    required this.isUser,
    this.isComplete = true,
    this.id,
    Iterable<String>? appliedActionKeys,
  }) {
    if (appliedActionKeys != null) {
      this.appliedActionKeys.addAll(appliedActionKeys);
    }
  }

  String text;
  final bool isUser;
  bool isComplete;
  String? id;

  /// Action chips the user already applied from this bubble (persisted in the
  /// local branch tree so reopen / conversation switch keeps them applied).
  final Set<String> appliedActionKeys = {};
}
