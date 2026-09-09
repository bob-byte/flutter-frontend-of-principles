class AiChatMessageModel {
  const AiChatMessageModel({
    required this.id,
    required this.conversationId,
    required this.role,
    required this.content,
    required this.sortOrder,
    required this.createdAt,
  });

  final String id;
  final String conversationId;
  final String role;
  final String content;
  final int sortOrder;
  final DateTime createdAt;

  bool get isUser => role == 'user';

  AiChatMessageModel copyWith({
    String? id,
    String? conversationId,
    String? role,
    String? content,
    int? sortOrder,
    DateTime? createdAt,
  }) {
    return AiChatMessageModel(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      role: role ?? this.role,
      content: content ?? this.content,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, Object?> toMap() => {
    'id': id,
    'conversationId': conversationId,
    'role': role,
    'content': content,
    'sortOrder': sortOrder,
    'createdAt': createdAt.toUtc().toIso8601String(),
  };

  factory AiChatMessageModel.fromMap(Map<String, Object?> map) {
    return AiChatMessageModel(
      id: '${map['id'] ?? ''}',
      conversationId: '${map['conversationId'] ?? ''}',
      role: '${map['role'] ?? ''}',
      content: '${map['content'] ?? ''}',
      sortOrder: (map['sortOrder'] as num?)?.toInt() ?? 0,
      createdAt:
          DateTime.tryParse('${map['createdAt'] ?? ''}')?.toUtc() ??
          DateTime.now().toUtc(),
    );
  }

  Map<String, dynamic> toDtoJson() => {
    'id': id,
    'role': role,
    'content': content,
    'sortOrder': sortOrder,
    'createdAt': createdAt.toUtc().toIso8601String(),
  };

  factory AiChatMessageModel.fromDtoJson(
    Map<String, dynamic> json, {
    required String conversationId,
  }) {
    return AiChatMessageModel(
      id: '${json['id'] ?? json['Id'] ?? ''}',
      conversationId: conversationId,
      role: '${json['role'] ?? json['Role'] ?? ''}'.toLowerCase(),
      content: '${json['content'] ?? json['Content'] ?? ''}',
      sortOrder: _readInt(json['sortOrder'] ?? json['SortOrder']) ?? 0,
      createdAt:
          DateTime.tryParse(
            '${json['createdAt'] ?? json['CreatedAt'] ?? ''}',
          )?.toUtc() ??
          DateTime.now().toUtc(),
    );
  }

  static int? _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value');
  }
}
