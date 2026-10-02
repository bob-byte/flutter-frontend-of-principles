class RecommendedGoal {
  const RecommendedGoal({required this.name, required this.reason});

  final String name;
  final String reason;

  factory RecommendedGoal.fromJson(Map<String, dynamic> json) {
    return RecommendedGoal(
      name: (json['name'] ?? json['Name'] ?? json['text'] ?? json['Text'] ?? '')
          .toString()
          .trim(),
      reason:
          (json['reason'] ??
                  json['Reason'] ??
                  json['reasonToFollow'] ??
                  json['ReasonToFollow'] ??
                  '')
              .toString()
              .trim(),
    );
  }
}
