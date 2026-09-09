import 'ai_chat_message.dart';

class AiConversation {
  const AiConversation({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.messages = const [],
    this.serverId,
    this.lastModified,
    this.isDeleted = false,
    this.hasAiTitle = false,
  });

  /// Client UUID used as the stable local and sync key.
  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<AiChatMessageModel> messages;
  final int? serverId;
  final DateTime? lastModified;
  final bool isDeleted;

  /// True after a successful AI title response (vs placeholder from first prompt).
  final bool hasAiTitle;

  AiConversation copyWith({
    String? id,
    String? title,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<AiChatMessageModel>? messages,
    int? serverId,
    bool clearServerId = false,
    DateTime? lastModified,
    bool? isDeleted,
    bool? hasAiTitle,
  }) {
    return AiConversation(
      id: id ?? this.id,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      messages: messages ?? this.messages,
      serverId: clearServerId ? null : (serverId ?? this.serverId),
      lastModified: lastModified ?? this.lastModified,
      isDeleted: isDeleted ?? this.isDeleted,
      hasAiTitle: hasAiTitle ?? this.hasAiTitle,
    );
  }

  Map<String, Object?> toRow() => {
    'id': id,
    'serverId': serverId,
    'title': title,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'lastModified': (lastModified ?? updatedAt).toUtc().toIso8601String(),
    'isDeleted': isDeleted ? 1 : 0,
    'hasAiTitle': hasAiTitle ? 1 : 0,
  };

  factory AiConversation.fromRow(
    Map<String, Object?> row, {
    List<AiChatMessageModel> messages = const [],
  }) {
    return AiConversation(
      id: '${row['id'] ?? ''}',
      serverId: (row['serverId'] as num?)?.toInt(),
      title: '${row['title'] ?? ''}',
      createdAt:
          DateTime.tryParse('${row['createdAt'] ?? ''}')?.toUtc() ??
          DateTime.now().toUtc(),
      updatedAt:
          DateTime.tryParse('${row['updatedAt'] ?? ''}')?.toUtc() ??
          DateTime.now().toUtc(),
      lastModified: DateTime.tryParse('${row['lastModified'] ?? ''}')?.toUtc(),
      isDeleted: (row['isDeleted'] as num?)?.toInt() == 1,
      hasAiTitle: (row['hasAiTitle'] as num?)?.toInt() == 1,
      messages: messages,
    );
  }

  Map<String, dynamic> toDtoJson({bool includeMessages = true}) => {
    if (serverId != null && serverId! > 0) 'id': serverId,
    'clientId': id,
    'title': title,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    if (includeMessages) 'messages': [for (final m in messages) m.toDtoJson()],
  };

  factory AiConversation.fromDtoJson(Map<String, dynamic> json) {
    final clientId = '${json['clientId'] ?? json['ClientId'] ?? ''}'.trim();
    final serverId = _readInt(json['id'] ?? json['Id']);
    final id = clientId.isNotEmpty
        ? clientId
        : (serverId != null ? 'S$serverId' : '');
    final messagesRaw = json['messages'] ?? json['Messages'];
    final messages = <AiChatMessageModel>[];
    if (messagesRaw is List) {
      for (final item in messagesRaw) {
        if (item is! Map) continue;
        messages.add(
          AiChatMessageModel.fromDtoJson(
            Map<String, dynamic>.from(item),
            conversationId: id,
          ),
        );
      }
      messages.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    }

    return AiConversation(
      id: id,
      serverId: serverId,
      title: '${json['title'] ?? json['Title'] ?? ''}',
      createdAt:
          DateTime.tryParse(
            '${json['createdAt'] ?? json['CreatedAt'] ?? ''}',
          )?.toUtc() ??
          DateTime.now().toUtc(),
      updatedAt:
          DateTime.tryParse(
            '${json['updatedAt'] ?? json['UpdatedAt'] ?? ''}',
          )?.toUtc() ??
          DateTime.now().toUtc(),
      lastModified: DateTime.tryParse(
        '${json['updatedAt'] ?? json['UpdatedAt'] ?? ''}',
      )?.toUtc(),
      hasAiTitle: true,
      messages: messages,
    );
  }

  static int? _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value');
  }
}
