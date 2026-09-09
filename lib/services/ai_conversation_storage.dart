import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../core/storage/local_db.dart';
import '../models/ai_chat_message.dart';
import '../models/ai_conversation.dart';

class AiConversationStorage {
  AiConversationStorage(this._localDb);

  final LocalDb? _localDb;
  static const _prefsKey = 'ai_conversations_v1';
  static final _random = Random.secure();

  bool get _useWebStorage => kIsWeb || _localDb == null;

  Future<Database> get _database async => _localDb!.database;

  static String newId() {
    final millis = DateTime.now().toUtc().millisecondsSinceEpoch;
    final suffix = List.generate(
      8,
      (_) => _random.nextInt(16).toRadixString(16),
    ).join();
    return 'c$millis$suffix';
  }

  Future<List<AiConversation>> listConversations({
    bool includeDeleted = false,
  }) async {
    if (_useWebStorage) {
      final all = await _loadWeb();
      final filtered = includeDeleted
          ? all
          : all.where((c) => !c.isDeleted).toList();
      filtered.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return [for (final c in filtered) c.copyWith(messages: const [])];
    }

    final db = await _database;
    final rows = await db.query(
      'ai_conversations',
      where: includeDeleted ? null : 'isDeleted = 0 OR isDeleted IS NULL',
      orderBy: 'updatedAt DESC',
    );
    return [for (final row in rows) AiConversation.fromRow(row)];
  }

  Future<AiConversation?> getConversation(
    String id, {
    bool includeMessages = true,
  }) async {
    if (_useWebStorage) {
      final all = await _loadWeb();
      for (final c in all) {
        if (c.id == id && !c.isDeleted) {
          return includeMessages ? c : c.copyWith(messages: const []);
        }
        if (c.serverId != null && c.serverId.toString() == id && !c.isDeleted) {
          return includeMessages ? c : c.copyWith(messages: const []);
        }
      }
      return null;
    }

    final db = await _database;
    final byId = await db.query(
      'ai_conversations',
      where: 'id = ? AND (isDeleted = 0 OR isDeleted IS NULL)',
      whereArgs: [id],
      limit: 1,
    );
    Map<String, Object?>? row = byId.isEmpty ? null : byId.first;
    if (row == null) {
      final serverId = int.tryParse(id);
      if (serverId != null) {
        final byServer = await db.query(
          'ai_conversations',
          where: 'serverId = ? AND (isDeleted = 0 OR isDeleted IS NULL)',
          whereArgs: [serverId],
          limit: 1,
        );
        if (byServer.isNotEmpty) row = byServer.first;
      }
    }
    if (row == null) return null;

    final messages = includeMessages
        ? await _loadMessages(db, row['id'] as String)
        : const <AiChatMessageModel>[];
    return AiConversation.fromRow(row, messages: messages);
  }

  Future<void> saveConversation(AiConversation conversation) async {
    final now = DateTime.now().toUtc();
    final stored = conversation.copyWith(
      updatedAt: conversation.updatedAt,
      lastModified: now,
    );

    if (_useWebStorage) {
      final all = await _loadWeb();
      final index = all.indexWhere((c) => c.id == stored.id);
      if (index >= 0) {
        all[index] = stored;
      } else {
        all.add(stored);
      }
      await _saveWeb(all);
      return;
    }

    final db = await _database;
    await db.transaction((txn) async {
      await txn.insert(
        'ai_conversations',
        stored.toRow(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.delete(
        'ai_messages',
        where: 'conversationId = ?',
        whereArgs: [stored.id],
      );
      for (final message in stored.messages) {
        await txn.insert(
          'ai_messages',
          message.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<void> deleteConversation(String id) async {
    if (_useWebStorage) {
      final all = await _loadWeb();
      final index = all.indexWhere((c) => c.id == id);
      if (index < 0) return;
      all[index] = all[index].copyWith(
        isDeleted: true,
        updatedAt: DateTime.now().toUtc(),
        lastModified: DateTime.now().toUtc(),
      );
      await _saveWeb(all);
      return;
    }

    final db = await _database;
    await db.update(
      'ai_conversations',
      {
        'isDeleted': 1,
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
        'lastModified': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> purgeDeleted(String id) async {
    if (_useWebStorage) {
      final all = await _loadWeb();
      all.removeWhere((c) => c.id == id);
      await _saveWeb(all);
      return;
    }

    final db = await _database;
    await db.delete(
      'ai_messages',
      where: 'conversationId = ?',
      whereArgs: [id],
    );
    await db.delete('ai_conversations', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<AiChatMessageModel>> _loadMessages(
    DatabaseExecutor db,
    String conversationId,
  ) async {
    final rows = await db.query(
      'ai_messages',
      where: 'conversationId = ?',
      whereArgs: [conversationId],
      orderBy: 'sortOrder ASC, createdAt ASC',
    );
    return [for (final row in rows) AiChatMessageModel.fromMap(row)];
  }

  Future<List<AiConversation>> _loadWeb() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return [
      for (final item in list)
        if (item is Map)
          AiConversation.fromDtoJson(Map<String, dynamic>.from(item)).copyWith(
            hasAiTitle: item['hasAiTitle'] == true || item['hasAiTitle'] == 1,
            isDeleted: item['isDeleted'] == true || item['isDeleted'] == 1,
            serverId: item['serverId'] is num
                ? (item['serverId'] as num).toInt()
                : int.tryParse('${item['serverId'] ?? ''}'),
          ),
    ];
  }

  Future<void> _saveWeb(List<AiConversation> conversations) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode([
      for (final c in conversations)
        {
          ...c.toDtoJson(),
          'serverId': c.serverId,
          'hasAiTitle': c.hasAiTitle,
          'isDeleted': c.isDeleted,
        },
    ]);
    await prefs.setString(_prefsKey, encoded);
  }
}
