import 'dart:convert';

import 'helper_chat_message.dart';

class HelperChatNode {
  HelperChatNode._(this.message, this.parent);

  /// Null only for the tree root. Mutable so [HelperChatTree.restore] can
  /// rebind decoded nodes onto the caller's thread message instances.
  ChatMessage? message;
  final HelperChatNode? parent;

  /// Alternative next turns (versions); [selected] is on the visible thread.
  final List<HelperChatNode> children = [];
  int selected = 0;

  HelperChatNode? get activeChild => children.isEmpty
      ? null
      : children[selected.clamp(0, children.length - 1)];
}

/// Branching Helper thread: editing a prompt or retrying a reply adds a sibling
/// version instead of overwriting it. The visible thread follows each node's
/// selected child.
class HelperChatTree {
  HelperChatTree();

  factory HelperChatTree.linear(Iterable<ChatMessage> messages) {
    final tree = HelperChatTree();
    for (final m in messages) {
      tree.append(m);
    }
    return tree;
  }

  /// Reuses the saved version tree when its active thread still matches (or is
  /// a prefix of) the synced [thread]; otherwise starts over from [thread].
  /// Another device can only append to or replace the synced thread.
  ///
  /// On a successful match, active-path nodes are rebound to [thread]'s
  /// message instances so identity-based lookups ([addVersion], etc.) work
  /// with the objects the caller already holds.
  factory HelperChatTree.restore(List<ChatMessage> thread, String? encoded) {
    final saved = encoded == null ? null : _tryDecode(encoded);
    if (saved != null) {
      final path = saved.activePath();
      // Empty path is a valid prefix (new/empty local tree before sync appends).
      var matches = path.length <= thread.length;
      for (var i = 0; matches && i < path.length; i++) {
        matches =
            path[i].isUser == thread[i].isUser &&
            path[i].text == thread[i].text;
      }
      if (matches) {
        saved._rebindActivePath(thread);
        for (final m in thread.skip(path.length)) {
          saved.append(m);
        }
        return saved;
      }
    }
    return HelperChatTree.linear(thread);
  }

  final HelperChatNode _root = HelperChatNode._(null, null);
  final Map<ChatMessage, HelperChatNode> _nodes = Map.identity();

  List<ChatMessage> activePath() {
    final out = <ChatMessage>[];
    var node = _root.activeChild;
    while (node != null) {
      out.add(node.message!);
      node = node.activeChild;
    }
    return out;
  }

  /// Adds [message] after the last visible turn.
  void append(ChatMessage message) {
    var tail = _root;
    while (tail.activeChild != null) {
      tail = tail.activeChild!;
    }
    _addChild(tail, message);
  }

  /// Adds [message] as a new version of [existing] and selects it.
  void addVersion(ChatMessage existing, ChatMessage message) {
    final parent = _nodes[existing]?.parent;
    if (parent == null) return;
    _addChild(parent, message);
  }

  /// 1-based position of [message] among its versions, and the version count.
  ({int index, int count}) versionOf(ChatMessage message) {
    final node = _nodes[message];
    final siblings = node?.parent?.children;
    if (node == null || siblings == null) return (index: 1, count: 1);
    return (index: siblings.indexOf(node) + 1, count: siblings.length);
  }

  /// Moves [message]'s slot [delta] versions over. False when out of range.
  bool selectVersion(ChatMessage message, int delta) {
    final node = _nodes[message];
    final parent = node?.parent;
    if (node == null || parent == null) return false;
    final next = parent.children.indexOf(node) + delta;
    if (next < 0 || next >= parent.children.length) return false;
    parent.selected = next;
    return true;
  }

  /// Drops [message] with its replies and falls back to the previous version.
  void remove(ChatMessage message) {
    final node = _nodes[message];
    final parent = node?.parent;
    if (node == null || parent == null) return;
    final index = parent.children.indexOf(node);
    parent.children.removeAt(index);
    _forget(node);
    if (parent.selected > index || (parent.selected == index && index > 0)) {
      parent.selected--;
    }
    if (parent.selected >= parent.children.length) {
      parent.selected = parent.children.isEmpty
          ? 0
          : parent.children.length - 1;
    }
  }

  bool get hasVersions {
    bool visit(HelperChatNode node) =>
        node.children.length > 1 || node.children.any(visit);
    return visit(_root);
  }

  String encode() => jsonEncode(_nodeToJson(_root));

  void _addChild(HelperChatNode parent, ChatMessage message) {
    final node = HelperChatNode._(message, parent);
    parent.children.add(node);
    parent.selected = parent.children.length - 1;
    _nodes[message] = node;
  }

  void _forget(HelperChatNode node) {
    final message = node.message;
    if (message != null) _nodes.remove(message);
    for (final child in node.children) {
      _forget(child);
    }
  }

  /// Point active-path nodes at [thread] messages (same text/role prefix),
  /// copying persisted applied-action keys onto those instances.
  void _rebindActivePath(List<ChatMessage> thread) {
    var node = _root.activeChild;
    var i = 0;
    while (node != null && i < thread.length) {
      final old = node.message!;
      final next = thread[i];
      if (!identical(old, next)) {
        next.appliedActionKeys.addAll(old.appliedActionKeys);
        _nodes.remove(old);
        node.message = next;
        _nodes[next] = node;
      }
      node = node.activeChild;
      i++;
    }
  }

  static Map<String, dynamic> _nodeToJson(HelperChatNode node) {
    final message = node.message;
    final children = [
      for (final child in node.children)
        // Skip a reply that is still streaming with no text yet.
        if (child.message!.isComplete || child.message!.text.isNotEmpty)
          _nodeToJson(child),
    ];
    return {
      if (message != null) ...{
        'id': message.id,
        'text': message.text,
        'isUser': message.isUser,
        if (message.appliedActionKeys.isNotEmpty)
          'appliedActionKeys': message.appliedActionKeys.toList(),
      },
      'selected': node.selected.clamp(
        0,
        children.isEmpty ? 0 : children.length - 1,
      ),
      'children': children,
    };
  }

  static HelperChatTree? _tryDecode(String encoded) {
    try {
      final json = jsonDecode(encoded);
      if (json is! Map) return null;
      final tree = HelperChatTree();
      tree._readChildren(tree._root, Map<String, dynamic>.from(json));
      return tree;
    } catch (_) {
      return null;
    }
  }

  void _readChildren(HelperChatNode parent, Map<String, dynamic> json) {
    final children = json['children'];
    if (children is List) {
      for (final raw in children) {
        if (raw is! Map) continue;
        final child = Map<String, dynamic>.from(raw);
        final message = ChatMessage(
          id: child['id'] as String?,
          text: '${child['text'] ?? ''}',
          isUser: child['isUser'] == true,
          appliedActionKeys: _readAppliedActionKeys(child['appliedActionKeys']),
        );
        final node = HelperChatNode._(message, parent);
        parent.children.add(node);
        _nodes[message] = node;
        _readChildren(node, child);
      }
    }
    final selected = json['selected'];
    parent.selected = selected is num ? selected.toInt() : 0;
  }

  static Iterable<String>? _readAppliedActionKeys(Object? raw) {
    if (raw is! List || raw.isEmpty) return null;
    return [
      for (final key in raw)
        if ('$key'.trim().isNotEmpty) '$key',
    ];
  }
}
