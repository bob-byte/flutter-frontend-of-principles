import 'package:flutter_test/flutter_test.dart';
import 'package:principles_app/models/helper_chat_message.dart';
import 'package:principles_app/models/helper_chat_tree.dart';

void main() {
  test('restore keeps empty saved tree and appends synced thread', () {
    final empty = HelperChatTree();
    final encoded = empty.encode();
    final thread = [
      ChatMessage(text: 'Hi', isUser: true),
      ChatMessage(text: 'Hello', isUser: false),
    ];

    final restored = HelperChatTree.restore(thread, encoded);

    expect(restored.activePath().map((m) => m.text), ['Hi', 'Hello']);
    expect(identical(restored.activePath()[0], thread[0]), isTrue);
    expect(identical(restored.activePath()[1], thread[1]), isTrue);
  });

  test('restore keeps versions when active path is a prefix of thread', () {
    final tree = HelperChatTree();
    final first = ChatMessage(text: 'A', isUser: true);
    final reply = ChatMessage(text: 'B', isUser: false);
    final alt = ChatMessage(text: 'A2', isUser: true);
    tree.append(first);
    tree.append(reply);
    tree.addVersion(first, alt);

    // Active path is A2 only (no reply yet).
    expect(tree.activePath().map((m) => m.text), ['A2']);

    final synced = [
      ChatMessage(text: 'A2', isUser: true),
      ChatMessage(text: 'B2', isUser: false),
    ];
    final restored = HelperChatTree.restore(synced, tree.encode());

    expect(restored.activePath().map((m) => m.text), ['A2', 'B2']);
    expect(restored.versionOf(restored.activePath().first).count, 2);
    // Rebinding keeps the caller's thread instances for identity lookups.
    expect(identical(restored.activePath().first, synced.first), isTrue);
    expect(identical(restored.activePath().last, synced.last), isTrue);
  });

  test('restore rebinds so addVersion works with thread message instances', () {
    final tree = HelperChatTree();
    final user = ChatMessage(id: 'u1', text: 'Q', isUser: true);
    final reply = ChatMessage(id: 'a1', text: 'A1', isUser: false);
    tree.append(user);
    tree.append(reply);
    tree.addVersion(reply, ChatMessage(id: 'a2', text: 'A2', isUser: false));

    final thread = [
      ChatMessage(id: 'u1', text: 'Q', isUser: true),
      ChatMessage(id: 'a2', text: 'A2', isUser: false),
    ];
    final restored = HelperChatTree.restore(thread, tree.encode());
    final alt = ChatMessage(id: 'a3', text: 'A3', isUser: false);
    restored.addVersion(thread.last, alt);

    expect(restored.activePath().last.text, 'A3');
    expect(restored.versionOf(thread.last).count, 3);
  });

  test('encode/decode preserves appliedActionKeys', () {
    final tree = HelperChatTree();
    final user = ChatMessage(text: 'Add a goal', isUser: true);
    final reply = ChatMessage(text: 'Sure', isUser: false);
    reply.appliedActionKeys.add('goal:run daily');
    tree.append(user);
    tree.append(reply);

    final thread = [
      ChatMessage(text: 'Add a goal', isUser: true),
      ChatMessage(text: 'Sure', isUser: false),
    ];
    final restored = HelperChatTree.restore(thread, tree.encode());

    expect(thread.last.appliedActionKeys, {'goal:run daily'});
    expect(restored.activePath().last.appliedActionKeys, {'goal:run daily'});
  });

  test('restore falls back to linear when active path diverges', () {
    final tree = HelperChatTree.linear([
      ChatMessage(text: 'Local', isUser: true),
    ]);
    final restored = HelperChatTree.restore([
      ChatMessage(text: 'Remote', isUser: true),
    ], tree.encode());

    expect(restored.activePath().single.text, 'Remote');
    expect(restored.hasVersions, isFalse);
  });
}
