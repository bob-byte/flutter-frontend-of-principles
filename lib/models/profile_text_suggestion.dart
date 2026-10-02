class ProfileTextSuggestion {
  const ProfileTextSuggestion({required this.text, required this.reason});

  final String text;
  final String reason;

  factory ProfileTextSuggestion.fromJson(Map<String, dynamic> json) {
    return ProfileTextSuggestion(
      text: (json['text'] ?? json['Text'] ?? json['Suggestion'] ?? '')
          .toString()
          .trim(),
      reason: (json['reason'] ?? json['Reason'] ?? json['ReasonToFollow'] ?? '')
          .toString()
          .trim(),
    );
  }
}

enum ProfileTextKind { slogan, mission }
