import 'package:flutter/material.dart';

import '../core/theme/task_theme_palette.dart';
import '../l10n/task_strings.dart';

/// Popup used in Tasks and Settings to pick one of the four UI themes.
class UiThemeSwitcher extends StatelessWidget {
  const UiThemeSwitcher({
    super.key,
    required this.selected,
    required this.onSelected,
    this.compact = false,
  });

  final TasksUiTheme selected;
  final ValueChanged<TasksUiTheme> onSelected;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final strings = TaskStrings.of(context);
    return PopupMenuButton<TasksUiTheme>(
      tooltip: strings.taskUiThemeTooltip,
      initialValue: selected,
      onSelected: onSelected,
      offset: const Offset(0, 44),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (context) => TasksUiTheme.values
          .map(
            (theme) => PopupMenuItem(
              value: theme,
              child: Row(
                children: [
                  ThemeSwatch(theme: theme, selected: theme == selected),
                  const SizedBox(width: 10),
                  Text(theme.label(strings)),
                ],
              ),
            ),
          )
          .toList(),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: compact ? 0 : 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ThemeSwatch(theme: selected, selected: true, compact: true),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }
}

class ThemeSwatch extends StatelessWidget {
  const ThemeSwatch({
    super.key,
    required this.theme,
    required this.selected,
    this.compact = false,
  });

  final TasksUiTheme theme;
  final bool selected;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final palette = TasksUiPalette.of(theme);
    final size = compact ? 22.0 : 18.0;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: palette.primaryGradient,
        border: Border.all(
          color: selected ? palette.textPrimary : Colors.transparent,
          width: selected ? 2 : 0,
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: palette.primary.withValues(alpha: 0.35),
                  blurRadius: 6,
                ),
              ]
            : null,
      ),
    );
  }
}
