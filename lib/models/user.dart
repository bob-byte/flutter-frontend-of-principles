class User {
  User({
    this.localId,
    this.id,
    this.name,
    this.mainSlogan,
    this.mission,
    this.email,
    this.gender,
    this.hasSeenRoadGuide = false,
    this.lastModified,
  });

  final int? localId;
  final int? id;
  final String? name;
  final String? mainSlogan;
  final String? mission;
  final String? email;
  final int? gender;
  final bool hasSeenRoadGuide;
  final DateTime? lastModified;

  User copyWith({
    int? localId,
    int? id,
    String? name,
    String? mainSlogan,
    String? mission,
    String? email,
    int? gender,
    bool? hasSeenRoadGuide,
    DateTime? lastModified,
  }) {
    return User(
      localId: localId ?? this.localId,
      id: id ?? this.id,
      name: name ?? this.name,
      mainSlogan: mainSlogan ?? this.mainSlogan,
      mission: mission ?? this.mission,
      email: email ?? this.email,
      gender: gender ?? this.gender,
      hasSeenRoadGuide: hasSeenRoadGuide ?? this.hasSeenRoadGuide,
      lastModified: lastModified ?? this.lastModified,
    );
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      localId: _asInt(json['localId'] ?? json['LocalId']),
      id: _asInt(json['id'] ?? json['Id']),
      name: _asString(json['name'] ?? json['Name']),
      mainSlogan: _asString(json['mainSlogan'] ?? json['MainSlogan']),
      mission: _asString(json['mission'] ?? json['Mission']),
      email: _asString(json['email'] ?? json['Email']),
      gender: _asInt(json['gender'] ?? json['Gender']),
      hasSeenRoadGuide: _asBool(
        json['hasSeenRoadGuide'] ?? json['HasSeenRoadGuide'],
      ),
      lastModified: _asDate(json['lastModified'] ?? json['LastModified']),
    );
  }

  Map<String, dynamic> toJson() => {
    if (localId != null) 'localId': localId,
    if (id != null) 'id': id,
    'name': name,
    'mainSlogan': mainSlogan,
    'mission': mission,
    'email': email,
    if (gender != null) 'gender': gender,
    'hasSeenRoadGuide': hasSeenRoadGuide,
    if (lastModified != null)
      'lastModified': lastModified!.toUtc().toIso8601String(),
  };

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  static String? _asString(dynamic value) {
    if (value == null) return null;
    return value.toString();
  }

  static bool _asBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      return value == '1' || value.toLowerCase() == 'true';
    }
    return false;
  }

  static DateTime? _asDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value.toUtc();
    return DateTime.tryParse(value.toString())?.toUtc();
  }
}
