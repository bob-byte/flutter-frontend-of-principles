import 'dart:convert';

import '../../models/helper_chat_action.dart';

/// Parses and strips the trailing `<<<ACTIONS>>>…<<<END>>>` block from helper replies.
class HelperChatActionsParseResult {
  const HelperChatActionsParseResult({
    required this.displayText,
    required this.actions,
  });

  final String displayText;
  final List<HelperChatAction> actions;
}

final _actionsBlockPattern = RegExp(
  r'<<<ACTIONS>>>\s*([\s\S]*?)\s*<<<END>>>',
  caseSensitive: false,
);

HelperChatActionsParseResult parseHelperChatActions(
  String raw, {
  bool parseActions = true,
}) {
  // While streaming, hide a partial ACTIONS trailer even before <<<END>>>.
  if (!parseActions) {
    final start = RegExp(
      r'<<<ACTIONS>>>',
      caseSensitive: false,
    ).firstMatch(raw);
    if (start == null) {
      return HelperChatActionsParseResult(displayText: raw, actions: const []);
    }
    return HelperChatActionsParseResult(
      displayText: raw.substring(0, start.start).trimRight(),
      actions: const [],
    );
  }

  final match = _actionsBlockPattern.firstMatch(raw);
  if (match == null) {
    final start = RegExp(
      r'<<<ACTIONS>>>',
      caseSensitive: false,
    ).firstMatch(raw);
    if (start != null) {
      return HelperChatActionsParseResult(
        displayText: raw.substring(0, start.start).trimRight(),
        actions: const [],
      );
    }
    return HelperChatActionsParseResult(displayText: raw, actions: const []);
  }

  final displayText = raw.replaceFirst(_actionsBlockPattern, '').trimRight();
  final payload = (match.group(1) ?? '').trim();
  if (payload.isEmpty) {
    return HelperChatActionsParseResult(
      displayText: displayText,
      actions: const [],
    );
  }

  try {
    final decoded = jsonDecode(payload);
    final list = <HelperChatAction>[];
    if (decoded is List) {
      for (final item in decoded) {
        if (item is! Map) continue;
        final action = HelperChatAction.fromJson(
          Map<String, dynamic>.from(item),
        );
        if (action.title.trim().isEmpty) continue;
        list.add(action);
        if (list.length >= 5) break;
      }
    } else if (decoded is Map) {
      final action = HelperChatAction.fromJson(
        Map<String, dynamic>.from(decoded),
      );
      if (action.title.trim().isNotEmpty) {
        list.add(action);
      }
    }
    return HelperChatActionsParseResult(
      displayText: displayText,
      actions: list,
    );
  } catch (_) {
    return HelperChatActionsParseResult(
      displayText: displayText,
      actions: const [],
    );
  }
}

/// Text shown in the bubble / copied to clipboard (actions trailer removed).
String helperChatDisplayText(String raw) =>
    parseHelperChatActions(raw).displayText;
