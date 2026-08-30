import 'package:flutter/material.dart';

/// Builds a [TextSpan] that turns each [links] label into a tappable span.
///
/// [text] should already contain those labels (typically from an l10n string
/// with placeholders). Matching is longest-label-first so labels cannot
/// swallow each other.
TextSpan linkedTextSpan({
  required String text,
  required Map<String, VoidCallback> links,
  required TextStyle style,
  required TextStyle linkStyle,
}) {
  final labels = links.keys.where((label) => label.isNotEmpty).toList()
    ..sort((a, b) => b.length.compareTo(a.length));
  if (labels.isEmpty) {
    return TextSpan(text: text, style: style);
  }

  final pattern = RegExp(labels.map(RegExp.escape).join('|'));
  final children = <InlineSpan>[];
  var cursor = 0;
  for (final match in pattern.allMatches(text)) {
    if (match.start > cursor) {
      children.add(TextSpan(text: text.substring(cursor, match.start)));
    }
    final label = match.group(0)!;
    children.add(
      WidgetSpan(
        alignment: PlaceholderAlignment.baseline,
        baseline: TextBaseline.alphabetic,
        child: GestureDetector(
          onTap: links[label],
          child: Text(label, style: linkStyle),
        ),
      ),
    );
    cursor = match.end;
  }
  if (cursor < text.length) {
    children.add(TextSpan(text: text.substring(cursor)));
  }

  return TextSpan(style: style, children: children);
}
