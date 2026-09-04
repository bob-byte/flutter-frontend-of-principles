class RecommendedHabit {
  const RecommendedHabit({required this.name, required this.reasonToFollow});

  final String name;
  final String reasonToFollow;

  factory RecommendedHabit.fromJson(Map<String, dynamic> json) {
    return RecommendedHabit(
      name: (json['name'] ?? json['Name'] ?? '').toString().trim(),
      reasonToFollow: (json['reasonToFollow'] ?? json['ReasonToFollow'] ?? '')
          .toString()
          .trim(),
    );
  }
}
